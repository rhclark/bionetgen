
package BipartiteGraph;
# pragmas
use strict;
use warnings;
no warnings 'redefine';

# Perl Modules
use Class::Struct;
use List::Util qw(min max sum);
#use List::MoreUtils qw( uniq);
use Data::Dumper;

# BNG modules
use StructureGraph;
sub uniq (@) { my %seen = (); grep { not $seen{$_}++ } @_; }
	
struct BipartiteGraph => 
{ 
	'NodeList' => '@', # array of strings
	'EdgeList' => '@', # array of strings
	'Name' => '$', # a name which might come in handy to compare/combine rules
	# of the form <transformationstring>:<atomicpatternstring>:<edgetype>
	# or <wildcardpattern>:<atomicpatternstring>:Wildcard
	'NodeGroups' => '@' # array of arrayrefs, each being a ref to a group of nodes	
};

sub isAtomicPattern { return ($_[0] =~ '->') ? 0 : 1; }
sub isTransformation { return ($_[0] =~ '->') ? 1 : 0; }
sub isSyn { return ($_[0] =~ m/^\->/) ? 1 : 0; }
sub isDel { return ($_[0] =~ m/->$/) ? 1 : 0; }
sub isWildcard{ return ($_[0] =~ /\!\+/) ? 1 : 0; }
sub listHas
{
	my @list = @{$_[0]};
	my $check = $_[1];
	return 1 if grep ( $_ eq $check, @list);
	return 0;
}
sub checkAndAdd
{
	if (listHas(@_)==0) { push @$_[0], $_[1];}
	return;
}

sub reverseTransformation
{
	my $tr = shift @_; #unprettified
	my @splits = reverse split('->',prettify($tr));
	#my @splits2 = map ( join(',',sort split(',',$_ =~ s/\s//g)), @splits);
	sub clean { $_ =~ s/\s//g; return $_; }
	my @splits2 = map ( join(',',sort split(',',clean($_))), @splits);
	my $tr2 = unprettify(join '->',@splits2 );
	return $tr2;
}

sub makeAtomicPattern { return StructureGraph::makeAtomicPattern(@_); }
sub makeTransformation { return StructureGraph::makeTransformation(@_); }
sub printGraph 
{
	my $bpg = shift @_;
	my @nodelist = @{$bpg->{'NodeList'}};
	my @transf = grep ( $_ =~ /->/, @nodelist);
	my @ap = ();
	foreach my $item(@nodelist)
		{
		if ( $item =~ m/->/) { next;}
		else { push @ap, $item; }
		}
	
	my $string = "";
	$string .= "\n\nAtomicPatterns: ".(scalar @ap)."\n";
	$string .= join("", map prettify($_)."\n", @ap);
	$string .= "\n\nTransformations: ".(scalar @transf)."\n";
	$string .= join("", map prettify($_)."\n", @transf);
	$string .= "\n\nEdges: ".(scalar @{$bpg->{'EdgeList'}})."\n";
	$string .= join("", map $_."\n",@{$bpg->{'EdgeList'}});
	return $string;
	
}

sub prettify
{
	my $string = shift @_;
	my $arrow = '->';
	#print ($string, $string =~ /$arrow/, "\n");
	# check if it is a transformation
	if ($string =~ /$arrow/)
	{
		# see if arrow has spaces already
		if ($string =~ /\b$arrow\b/) { return $string;}
		else  
		{
			my @splits = split $arrow,$string;
			if (scalar @splits == 1) { push @splits,"0"; }
			elsif (length $splits[0] == 0) { $splits[0]="0";}
			return join(" -> ",map prettify($_), @splits);
		}
	}
	my $comma = ',';
	if ($string =~ /$comma/) 
	{
		if ($string =~ /\b$comma\b/) { return $string; }
		else 
		{ 
			my @splits = split $comma,$string;
			return join(" , ", @splits); 
		}
	} 
	if ($string =~ /$0^/) { return $string; } 
	#if ($string =~ /\(/)  { return $string; }
	#else { return $string."\(\)"; }
	return $string;
}

sub unprettify
{
	my $string = shift @_;
	$string =~ s/\s//g;
	$string =~ s/\(\)//g;
	$string =~ s/^0//g;
	$string =~ s/0$//g;
	return $string;
}


sub getReactantsProducts
{
	my $string = unprettify(shift @_);
	my @splits = split '->',$string;
	my @reac = ();
	my @prod = ();
	if (scalar @splits == 1) { @reac = ($splits[0]); }
	elsif (length $splits[0] == 0) { @prod = ($splits[1]); }
	else { @reac = split ',',$splits[0]; @prod = split ',',$splits[1]; }
	return (\@reac,\@prod);
}

sub getStructures
{
	my @nodelist = @{shift @_};
	my %structures = ('Mol'=>1,'Comp'=>1,'CompState'=>1,'BondState'=>1,'GraphOp'=>0,'Rule'=>0);
	my @nodes = grep( $structures{$_->{'Type'}}==1, @nodelist);
	return @nodes;
}
sub getContext
{
	my @nodelist = @{shift @_};
	my @nodes_struct = getStructures(\@nodelist);
	my @nodes = hasSide(\@nodes_struct,'both');
	my @context = ();
	
	# comp states
	my @compstates = hasType(\@nodes,'CompState');
	if (@compstates)
	{
		foreach my $node(@compstates)
		{
			my $string = makeAtomicPattern(\@nodes_struct,$node);
			if ($string) { push @context,$string;}
		}
	}
	
	# bond states
	my @bondstates = hasType(\@nodes,'BondState');
	foreach my $node(@bondstates)
	{
		my $string = makeAtomicPattern(\@nodes_struct,$node);
		if ($string) { push @context,$string;}
	}
	
	# unbound states
	my @comps = hasType(\@nodes,'Comp');
	my %unbound;
	foreach my $x(@comps) { $unbound{$x->{'ID'}}=1; }
	my @allbonds = hasType(\@nodelist,'BondState');
	my @allbondparents;
	foreach my $node(@allbonds) { push @allbondparents, @{$node->{'Parents'}}; }
	foreach my $x(@allbondparents) { $unbound{$x}=0; }
	foreach my $x(keys %unbound) 
	{ 
		if ($unbound{$x}) 
		{
			my $node = findNode(\@comps,$x);
			push @context,makeAtomicPattern(\@nodes_struct,$node);
		}
	}
	
	# mol nodes that do not have any components (hence identified by only label)
	my @mols = hasType(\@nodes,'Mol');
	my %havenocomps;
	foreach my $x(@mols) { $havenocomps{$x->{'ID'}}=1; }
	my @allcompparents;
	foreach my $node(@comps) { push @allcompparents, @{$node->{'Parents'}}; }
	foreach my $x(@allcompparents) { $havenocomps{$x}=0; }
	foreach my $x(keys %havenocomps) 
	{ 
		if ($havenocomps{$x}) 
		{
			my $node = findNode(\@mols,$x);
			push @context,makeAtomicPattern(\@nodes_struct,$node);
		}
	}
	
	return @context;
}

sub getSyndelContext
{
	my @nodelist = @{shift @_};
	my $op = shift @_;
	
	my $mol = findNode(\@nodelist,${$op->{'Parents'}}[0]);
	
	# get child components
	my @allcomps = hasType(\@nodelist,'Comp');
	my @comps = grep (${$_->{'Parents'}}[0] eq $mol->{'ID'}, @allcomps);
	my @comps_ids = map $_->{'ID'}, @comps;
	
	# get child component states
	my @allcompstates = hasType(\@nodelist,'CompState');
	my @compstates = ();
	foreach my $x(@allcompstates)
	{
		foreach my $y (@comps_ids)
			{
				if (${$x->{'Parents'}}[0] eq $y) { push @compstates,$x; }
			}
	}
	
	# get child bond states
	my %unbound;
	foreach my $y (@comps_ids) { $unbound{$y} = 1; }
			
	my @allbondstates = hasType(\@nodelist,'BondState');
	my @bondstates = ();
	foreach my $x(@allbondstates)
	{	
		my @parents = @{$x->{'Parents'}};
		foreach my $y (@comps_ids)
		{
			foreach my $z(@parents)
			{
			if ($y eq $z) 
				{
				push @bondstates,$x;
				$unbound{$z} = 0;
				}
			}
		}
	}
	
	my @unboundcomps = ();
	foreach my $x(keys %unbound)
	{
	if ($unbound{$x}) 
		{
		my $node = findNode(\@nodelist,$x);
		push @unboundcomps, $node;
		}
	}
	
	my @syndelnodes = (@compstates,@bondstates,@unboundcomps);
	my @syndel = ();
	foreach my $node(@syndelnodes) { push @syndel, makeAtomicPattern(\@nodelist,$node); }
	
	return @syndel;
}

sub makeEdge
{
	my %shortname = ( 'r'=>"Reactant", 'p'=>"Product", 'c'=>"Context", 's'=>"Syndel", 'w'=>"Wildcard", 'pp'=>"ProcessPair", 'co'=>"Cotransform" );
	
	my $node1 = shift @_;
	my $node2 = shift @_;
	my $rel = $shortname{shift @_};
	
	my $string = $node1.":".$node2.":".$rel;
	return $string;
	
}

sub findNode { return StructureGraph::findNode(@_); }
sub hasType { return StructureGraph::hasType(@_); }
sub hasSide { return StructureGraph::hasSide(@_); }
sub printHash {return StructureGraph::printHash(@_); }

sub findParents
{
	my $nodelist = shift @_;
	my $node = shift @_;
	return map findNode($nodelist,$_),@{$node->{'Parents'}};
}

sub combine
{
	my @bpgs = @{shift @_};
	my $bpgout = BipartiteGraph->new();
	
	foreach my $bpg(@bpgs)
		{
		push @{$bpgout->{'NodeList'}}, @{$bpg->{'NodeList'}};
		push @{$bpgout->{'EdgeList'}}, @{$bpg->{'EdgeList'}};
		}
	
	@{$bpgout->{'NodeList'}} = uniq @{$bpgout->{'NodeList'}};
	@{$bpgout->{'EdgeList'}} = uniq @{$bpgout->{'EdgeList'}};

	
	
	return $bpgout;

}
sub addWildcards
{
	my $bpg = shift @_;
	my @nodelist = @{$bpg->{'NodeList'}};
	my @ap = grep (isAtomicPattern($_),@nodelist);
	my @tr = grep (isTransformation($_),@nodelist);
	my @wildcards = grep (isWildcard($_), @ap);
	my @notwildcards = grep (!isWildcard($_), @ap);

	foreach my $wc(@wildcards)
		{
		my @splits = split '\+', $wc;
		my $string = $splits[0];
		
		my @matches = grep(index($_, $string) != -1, @notwildcards);
		foreach my $match(@matches)
			{
			my $edge = makeEdge($wc,$match,'w');
			push @{$bpg->{'EdgeList'}},$edge;
			}
		}
	return;
}
sub addProcessPairs
{
	my $bpg = shift @_;
	my @nodelist = @{$bpg->{'NodeList'}};
	my @trs = grep (isTransformation($_),@nodelist);
	
	my %checked;
	foreach my $tr(@trs) {$checked{$tr} = 0;}
	foreach my $tr(@trs)
		{
		if ($checked{$tr}) {next;}
		$checked{$tr} = 1;
		my $rev = reverseTransformation($tr);
		if(listHas(\@trs,$rev))
			{
			$checked{$rev} = 1;
			my $edge = makeEdge($tr,$rev,'pp');
			push @{$bpg->{'EdgeList'}},$edge;
			}
		}
}

sub makeRuleBipartiteGraph
{
	# from a rule structure graph
	my $rsg = shift @_;
	my $name = $rsg->{'Name'};
	my @nodelist = @{$rsg->{'NodeList'}};
	
	my $bpg = BipartiteGraph->new();
	$bpg->{'Name'} = $name;
	
	my @graphop = hasType(\@nodelist,'GraphOp');
	my @transf;
	# isolate the common context
	my @contexts = getContext(\@nodelist);
	
	#add edges for reactant, product, common context
	foreach my $op(@graphop)
	{
		my $tr = makeTransformation(\@nodelist,$op);
		# this is because we are currently not treating wildcard bond deletions
		if(length $tr == 0) { next; }
		
		push @{$bpg->{'NodeList'}}, $tr;
		push @transf, $tr;
		
		my ($reac,$prod) = getReactantsProducts($tr);
		push @{$bpg->{'NodeList'}}, @$reac, @$prod;
		foreach my $reactant (@$reac)
		{
			if (length $reactant == 0) {next;}
			my $edge = makeEdge($tr,$reactant,'r');
			push @{$bpg->{'NodeList'}}, $reactant;
			push @{$bpg->{'EdgeList'}}, $edge;
		}
		foreach my $product (@$prod)
		{
			if (length $product == 0) {next;}
			my $edge = makeEdge($tr,$product,'p');
			push @{$bpg->{'NodeList'}}, $product;
			push @{$bpg->{'EdgeList'}}, $edge;
		}
		foreach my $context(@contexts)
		{
			if (length $context == 0) {next;}
			my $edge = makeEdge($tr,$context,'c');
			push @{$bpg->{'NodeList'}}, $context;
			push @{$bpg->{'EdgeList'}}, $edge;
		}
		
		# add syndel edges
		if ($op->{'Name'} =~ /Mol/)
		{
			my @syndels = getSyndelContext(\@nodelist,$op);
			foreach my $syndel(@syndels)
			{
				if (length $syndel == 0) {next;}
				my $edge = makeEdge($tr,$syndel,'s');
				push @{$bpg->{'NodeList'}}, $syndel;
				push @{$bpg->{'EdgeList'}}, $edge;
			}
		}
	}
	#cotransforms
	foreach my $i(0..@graphop-1)
	{
		foreach my $j($i+1..@graphop-1)
		{
			my $tr1 = makeTransformation(\@nodelist,$graphop[$i]);
			my $tr2 = makeTransformation(\@nodelist,$graphop[$j]);
			next if (length($tr1) == 0 || length($tr2) == 0);
			next if ($tr1 eq $tr2);
			my $edge = makeEdge($tr1,$tr2,'co');
			push @{$bpg->{'EdgeList'}}, $edge;
		}
	}
	@{$bpg->{'NodeList'}} = uniq @{$bpg->{'NodeList'}};
	@{$bpg->{'EdgeList'}} = uniq @{$bpg->{'EdgeList'}};
	
	return $bpg;
}

sub makeGroups
{
	my $bpg = shift @_;

	my @nodelist = @{$bpg->{'NodeList'}};
	my @edgelist = @{$bpg->{'EdgeList'}};
	my @groups;
 	
	# create isgrouped to keep track of group assignments
	my %isgrouped;
	foreach my $node(@nodelist) {$isgrouped{$node} = 0;}
	
	# isolate and assign process pairs
	my @processpairs = grep(/ProcessPair/,@edgelist);
	foreach my $edge(@processpairs)
	{
		my @splits = split(':',$edge);
		my @trs = splice @splits,0,2;
		foreach my $tr(@trs) { $isgrouped{$tr} = 1; }
		push @groups,\@trs;
	}
	
	# identify unpaired transformations and add them to groups
	my @trs = grep(/->/,@nodelist);
	my @irr = grep( $isgrouped{$_} == 0, @trs);
	foreach my $irr(@irr) 
		{ 
		my @grp = ($irr); 
		$isgrouped{$irr} = 1;
		push @groups,\@grp; 
		}
	
	# isolate and assign reactant/product patterns
	# note: these will be assigned to multiple groups
	# this will be a problem during gml export
	# check at that point when you're assigning group ids
	my @reactprods = grep( /Reactant|Product/,@edgelist);
	foreach my $edge(@reactprods)
	{
		my @splits = split(':',$edge);
		my $tr = shift @splits;
		my $ap =shift @splits;
		foreach my $grp(@groups)
			{
			if (listHas($grp,$tr)) 
				{ 
				$isgrouped{$ap} = 1;
				push @$grp, $ap; 
				}
			}
	}
	
	# isolate and assign wildcard bonds
	# note: these will be assigned to multiple groups
	# this will be a problem during gml export
	# check at that point when you're assigning group ids
	my @wildcards = grep( /Wildcard/,@edgelist);
	foreach my $edge(@wildcards)
	{
		my @splits = split(':',$edge);
		my $wc = shift @splits;
		my $ap = shift @splits;
		foreach my $grp(@groups)
		{
		if (listHas($grp,$ap)) 
			{ 
			$isgrouped{$wc} = 1;
			push @$grp, $wc; 
			}
		}
	}
	
	foreach my $grp (@groups)
	{
		@$grp = uniq @$grp;
	}
	$bpg->{'NodeGroups'} = \@groups;
}

sub printGroups
{
	my $bpg = shift @_;
	my @groups = @{$bpg->{'NodeGroups'}};
	return map(("Group ".groupName($_)."\n".join("\n",@{$_})."\n\n",@groups));
}

sub groupName
{
	my @group = @{shift @_};
	my @trs = grep( /->/,@group);
	my $string;
	# assuming groups only have one process or a process pair
	if (@trs)
	{
		my $tr = $trs[0];
		if ( (index($tr, '~') != -1) )
			{
			# its a statechange
			my @sides = sort split('->',$tr);
			my @s1 = split(/\(|\)/,$sides[0]);
			my @s2 = split(/\(|\)/,$sides[1]);
			my $molname = $s1[0];
			my @s3 = split(/~/,$s1[1]);
			my @s4 = split(/~/,$s2[1]);
			my $compname = $s3[0];
			my @states = sort ($s3[1], $s4[1]);
			$string = $molname."(".$compname."~".$states[0]."~".$states[1].")";
			}
		elsif ( (index($tr, '!') != -1) )
			{
			# its a bond operation
			my @sides = split('->',$tr);
			my $side = (index($sides[0], ',') != -1) ? $sides[0]: $sides[1];
			my @mols = sort split(',',$side);
			$string = join(":",@mols);
			}
		else 
			{
			# its a molecule add or delete opn
			# is it add
			my $type = index($tr, '>')==(length($tr)-1) ? 'delete' : 'add';
			my $len = (length $tr) - 2;
			my $offset = ($type eq 'add') ? 2 : 0;
			#$string = "+/-:".substr($tr,$offset,$len);
			$string = substr($tr,$offset,$len);
			}
	}
	else 
	{ 
	# assuming this is a group with a single pattern in it
	$string = $group[0];
	}
	return $string;
}
sub analyzeGroups
{
	my $bpg = shift @_;
	my @nodelist = @{$bpg->{'NodeList'}};
	my @edgelist = @{$bpg->{'EdgeList'}};
	my @groups = @{$bpg->{'NodeGroups'}};
	# extend groups to include unassigned nodes
	my @assigned;
	foreach my $grp (@groups) { push @assigned, @$grp; }
	my @unassigned = grep !listHas(\@assigned,$_), @nodelist;
	foreach my $patt (@unassigned)
		{
			my @temp = ( $patt );
			push @groups, \@temp;
		}
	#print map join(" ", @{$_})."\n", @groups;
	
	# extract context
	my @context = grep( /Context/, @edgelist);
	my @syndel = grep( /Syndel/, @edgelist);
	my @cotransforms = grep ( /Cotransform/, @edgelist);

	my @syn = grep( (index($_, '->') == 0), @syndel);
	my @del = grep( (index($_, '->') != 0), @syndel);
	my @uni = ();
	my @bi = ();
	my @all = ();
	
	foreach my $i(0..@groups-1)
	{
		foreach my $j($i..@groups-1)
		{
			my @group1 = @{$groups[$i]};
			my @group2 = @{$groups[$j]};
			my $f = 0;
			my $r = 0;
			foreach my $p (@group1)
			{
				foreach my $q(@group2)
				{
					next if ($p eq $q); 
					# see if $p is a transformation and $q is a pattern
					if ((index($p, '->') != -1) and (index($q, '->') == -1) )
					{
						my $check = $p.":".$q.":";
						my @reverse = grep ( index($_, $check) != -1, (@context,@syn,@del) );
						my @forward = grep( index($_, $check) != -1, @del);
						if (@forward > 0) {$f++;}
						if (@reverse > 0) {$r++;}
					}
					# see if $q is a transformation and $p is a pattern
					if ((index($p, '->') == -1) and (index($q, '->') != -1) )
					{
						my $check = $q.":".$p.":";
						my @forward = grep ( index($_, $check) != -1, (@context,@syn,@del) );
						my @reverse = grep( index($_, $check) != -1, @del);
						if (@forward > 0) {$f++;}
						if (@reverse > 0) {$r++;}
					}
					# see if both $p and $q are transformations
					# check for cotransforms
					if ((index($p, '->') != -1) and (index($q, '->') != -1) )
					{
						my @check = grep index($_, $p) != -1, 
									grep index($_, $q) != -1, 
									@cotransforms;
						if (@check) { $f++; $r++; }
					}
				}
			}
			my $groupname1 = groupName(\@group1);
			my $groupname2 = groupName(\@group2);
			my $string1 = $groupname1." ".$groupname2;
			my $string2 = $groupname2." ".$groupname1;
			if ($f > 0 and $r > 0) { push @bi, $string1." ".$f." ".$r; }
			elsif ($f > 0 ) { push @uni, $string1." ".$f; }
			elsif ($r > 0 ) { push @uni, $string2." ".$r; }
		}
		push @all, groupName($groups[$i]);
	}
	return (\@bi,\@uni,\@all);
}

sub analyzeGroups2
{
	my $bpg = shift @_;
	my @nodelist = @{$bpg->{'NodeList'}};
	my @edgelist = @{$bpg->{'EdgeList'}};
	my @groups = @{$bpg->{'NodeGroups'}};
	# extend groups to include unassigned nodes
	my @assigned;
	foreach my $grp (@groups) { push @assigned, @$grp; }
	my @unassigned = grep !listHas(\@assigned,$_), @nodelist;
	foreach my $patt (@unassigned)
		{
			my @temp = ( $patt );
			push @groups, \@temp;
		}
	# now we need to assign a direction to each element of a group
	my @reac = grep( /Reactant/, @edgelist);
	my @prod = grep( /Product/, @edgelist);
	#my @syndel = grep( /Syndel/, @edgelist);
	
	my @sign_arr = ();
	# each group has a corresponding hash %sign that stores
	# the sign of each of its elements
	# @sign_arr is an array of references to those hashes
	
	foreach my $grp (@groups)
	{	
		my %sign;
		my @group = @$grp;
		my $n = scalar @group;
		my $first = shift @group;

		# if it is a singleton group, element is simply a pattern
		# assign +1 and move on
		if ($n==1) { $sign{$first} = +1; push @sign_arr, \%sign; next; }
		# if not a singleton group
		# first element will be a transformation
		# assign +1 unless it is a del transformation
		$sign{$first} = isDel($first) ? -1 : +1;
		# for the remaining transformation.
		# assign -1 unless it is a syn transformation
		my @trs = grep /->/, @group;
		foreach my $tr(@trs) { $sign{$tr} = isSyn($tr) ? +1 :  -1; }
		
		# separate patterns and wildcard patterns
		my @wc = grep /\!\+/, @group;
		my @temp = (@trs,@wc);
		my @patts = grep !listHas(\@temp,$_), @group;
		my @edges = grep index($_,$first.":")==0, @edgelist;
		my $syndelcheck = (isSyn($first)|isDel($first));

		# assigning signage to each pattern
		foreach my $patt(@patts)
		{
			my $str = ":".$patt.":";
			my @edges2 = grep index($_,$str)!=-1, @edges;
			if ($syndelcheck & @edges2) { $sign{$patt} = +1; next; }
			if (grep /Reactant/,@edges2) { $sign{$patt} = -1; next; }
			if (grep /Product/,@edges2) { $sign{$patt} = +1; next; }
		}
		
		# assigning signage to each wildcard within each group
		# note multiple assignments will happen across the groups
		# if the wildcard is clustered to different groups. that's okay!
		foreach my $wildcard(@wc)
		{
			my @matches = 	grep listHas(\@patts,$_),
							map { $_ =~ /.*:(.*):.*/; $1;}
							grep index($_,$wildcard)!=-1,
							grep /Wildcard/,
							@edgelist;
			$sign{$wildcard} = $sign{$matches[0]}; 
		}
		push @sign_arr, \%sign;
		#unshift @group, $first;	
	}
	#foreach my $sign(@sign_arr) { print printHash($sign); }
	# creating group names
	my %groupname;
	@groupname { 0..@groups-1 } = map groupName2($_), @groups;

	# initializing arrays holding positive & negative influences
	my @influences;
	
	# processing context
	my @context = grep( /Context/, @edgelist);
	foreach my $i(0..@groups-1)
	{
		foreach my $j(0..@groups-1)
		{
			my @group1 = @{$groups[$i]};
			my @group2 = @{$groups[$j]};
			my $pos = 0;
			my $neg = 0;
			foreach my $item1(@group1)
			{
				foreach my $item2(@group2)
				{
					#leave if items are equal
					next if ($item1 eq $item2);
					# context from item1->item2 is stored as
					# item2:item1:Context, with item2 usually a transf
					# and item1 usually a context
					my $str = $item2.":".$item1.":";
					my @conts = grep index($_,$str) == 0, @context;
					#
					# leave if there are no contexts
					next if (! @conts) ;
					foreach my $cont(@conts)
					{
						my $sign1 = $sign_arr[$i]{$item1};
						my $sign2 = $sign_arr[$j]{$item2};
						my $sign = $sign1*$sign2;
						if ($sign > 0) {$pos++;}
						if ($sign < 0) {$neg++;}
						if ($i==$j && @conts) {print $i." ".$j." ".$cont." ".$sign."\n";}
						#print join(" ",($cont, $groupname{$i}, $groupname{$j}, $sign1, $sign2, $sign))."\n";
					}
				}
			}
			if ($pos > 0) { push @influences, "+".$i.":".$j; }
			if ($neg > 0) { push @influences, "-".$i.":".$j; }
		}
	}
	# processing syndel context
	my @syndel = grep( /Syndel/, @edgelist);
	my @syn = grep( (index($_, '->') == 0), @syndel);
	my @del = grep( (index($_, '->') != 0), @syndel);
	foreach my $i(0..@groups-1)
	{
		my @group1 = @{$groups[$i]};
		my $syndelcheck = isSyn($group1[0])|isDel($group1[0]);
		next if ( ! $syndelcheck );
		
		my @trs = grep /->/, @group1;
		my @syn1; my @del1;
		foreach my $tr (@trs) 
		{
			push @del1, grep ( index($_,$tr) == 0, @del );
			push @syn1, grep ( index($_,$tr) == 0, @syn );
		}
		
		foreach my $j(0..@groups-1)
		{
			my $c_syn = 0;
			my $c_del = 0;
			my @group2 = @{$groups[$j]};
			foreach my $item(@group2)
			{
				my $str = ":".$item.":";
				if (grep (index($_,$str) != -1, @del1)) { $c_del++; }
				if (grep (index($_,$str) != -1, @syn1)) { $c_syn++; }
			}
			if ($c_del > 0)
			{
				push @influences, "-".$j.":".$i;
				push @influences, "-".$i.":".$j;
			}
			if ($c_syn > 0)
			{
				push @influences, "+".$i.":".$j;
			}
		}
	}
	
	# processing cotransforms
	my @cotransforms = grep ( /Cotransform/, @edgelist);
	foreach my $i(0..@groups-1)
	{	
		foreach my $j($i+1..@groups-1)
		{
			my @trs1 = grep ( /->/, @{$groups[$i]});
			my @trs2 = grep ( /->/, @{$groups[$j]});
			my $pos = 0;
			my $neg = 0;
			my $check = 0;
			foreach my $cotr(@cotransforms)
				{
				my @splits = split ":",$cotr;
				$check = 1 if (listHas(\@trs1,$splits[0]) && listHas(\@trs2,$splits[1]));
				$check = 1 if (listHas(\@trs2,$splits[0]) && listHas(\@trs1,$splits[1]));
				next if ($check==0);
				my $sign1 = listHas(\@trs1,$splits[0]) ? $sign_arr[$i]{$splits[0]} : $sign_arr[$j]{$splits[0]};
				my $sign2 = listHas(\@trs2,$splits[1]) ? $sign_arr[$j]{$splits[1]} : $sign_arr[$i]{$splits[1]};
				my $sign = -1*$sign1*$sign2;
				# note the additional -1 here when processing tr-tr signs to indicate causality
				if ($sign > 0) {$pos++;}
				if ($sign < 0) {$neg++;}
				}
			if ($pos > 0) { push @influences, "+".$i.":".$j; }
			if ($neg > 0) { push @influences, "-".$i.":".$j; }
		}
	}
	@influences = uniq @influences;
	return (\%groupname,\@influences);
}

sub groupName2
{
	my @group = @{shift @_};
	my $first = $group[0];
	if ($first !~ /->/) {return $first;}
	my ($lhs,$rhs) = map {$_=~ s/\s//g; $_;} split('->',prettify($first));
	if ($first =~ /~/) 
		{ 
		my ($mol,$comp) = ($1,$2) if $lhs =~ /^(.*)\((.*)~.*\)/;
		my $s1 = $1 if $lhs =~ /^.*\(.*~(.*)\)/;
		my $s2 = $1 if $rhs =~ /^.*\(.*~(.*)\)/;
		return $mol."(".$comp."~".$s1."->".$s2.")";
		}
	if ($first =~ /\!/)
		{
		if ($lhs =~ /\!/) 
			{
			my ($m1,$m2) = sort {$a cmp $b} split ",",$rhs;
			return $m1.":".$m2."->";
			}
		if ($rhs =~ /\!/) 
			{
			my ($m1,$m2) = sort {$a cmp $b} split ",",$lhs;
			return "->".$m1.":".$m2;
			}
		}
	# has to be a syn/del transform
	my @trs = grep /->/,@group;
	if ( @trs )
		{
		$first =~ s/->//g;
		return "->".$first."->";
		}
	return $first;
}
sub makeContactMap
{
	my $rsg = shift @_; # a rule structure graph
	my @nodelist =  grep $_->{'Type'} ne 'GraphOp',
					grep $_->{'Type'} ne 'Pattern', 
					grep $_->{'Type'} ne 'Rule',
					@{$rsg->{'NodeList'}};
	
	my @ap = uniq map makeAtomicPattern(\@nodelist,$_), @nodelist;

	my %cmap;
	my @bonds;
	
	# assigning mols
	my @mols = grep !/\(/, @ap;
	foreach my $mol(@mols) { $cmap{$mol} = {}; };

	
	# assigning comps
	my @comps =	grep !/~/,
				grep !/\!/, 
				grep /\(/,
				@ap;
	foreach my $str(@comps)
	{
		$str =~ /(.*)\((.*)\)/;
		my @arr = ();
		$cmap{$1}{$2} = \@arr;
	}
	
	
	# assigning comp states
	my @compstates = grep /~/,@ap;
	foreach my $str(@compstates)
	{
		$str =~ /(.*)\((.*)~(.*)\)/;
		push $cmap{$1}{$2}, $3;
	}

	# getting bonds
	my @bondstates = 	grep !/\!\+/,
						grep /\!/, @ap;
	foreach my $bond(@bondstates)
	{
		my @splits = split /\./, $bond;
		$splits[0] =~ /(.*)\((.*)\!/;
		my $mol1 = $1;
		my $comp1 = $2;
		$splits[1] =~ /(.*)\((.*)\!/;
		my $mol2 = $1; 
		my $comp2 = $2;
		push @bonds, $mol1." ".$comp1." ".$mol2." ".$comp2;
	}
	
	# building the contact map
	my @new_nodes = ();
	my $mol_ind = -1;
	foreach my $mol(keys %cmap)
	{
		$mol_ind++;
		push @new_nodes, StructureGraph::makeNode('Mol',$mol,$mol_ind);
		my $comp_ind = -1;
		foreach my $comp (keys $cmap{$mol})
		{
			$comp_ind++;
			my $c_id = $mol_ind.".".$comp_ind;
			my @parents = ($mol_ind);
			push @new_nodes, StructureGraph::makeNode('Comp',$comp,$c_id,\@parents);
			my $state_ind = -1;
			foreach my $compstate(@{$cmap{$mol}{$comp}})
			{
				$state_ind++;
				my $id = $mol_ind.".".$comp_ind.".".$state_ind;
				my @parents = ($c_id);
				push @new_nodes, StructureGraph::makeNode('CompState',$compstate,$id,\@parents);
			}
		}
	}
	foreach my $bond(@bonds)
	{
		my @splits = split " ",$bond;
		my $comp1 = findComp(\@new_nodes,$splits[0],$splits[1]);
		my $comp2 = findComp(\@new_nodes,$splits[2],$splits[3]);
		my @parents = sort ($comp1,$comp2);
		my $id = $parents[0].".1";
		push @new_nodes,StructureGraph::makeNode('BondState',"+",$id,\@parents); 
	}
	
	my $psg = StructureGraph::makeStructureGraph('ContactMap',\@new_nodes);
	#print StructureGraph::printGraph($psg);
	return $psg;
						
}
	
sub findComp
{
	my @nodelist = @{shift @_};
	my $molname = shift @_;
	my $compname = shift @_;
	my @nodes = grep $_->{'Name'} eq $molname, @nodelist;
	my $mol_id = $nodes[0]->{'ID'};
	@nodes = grep listHas($_->{'Parents'},$mol_id),
				grep $_->{'Name'} eq $compname,
				grep $_->{'Type'} eq 'Comp',
				@nodelist;
	
	return $nodes[0]->{'ID'};
}
	
	



1;