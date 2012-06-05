# -*- coding: utf-8 -*-
"""
Created on Tue Mar 13 15:45:25 2012

@author: proto
"""

from copy import copy,deepcopy
import random
import sys
import libsbml2bngl
import structures as st


def printSpecies(label,definition):
    molecules = []
    for tag, species in zip(label,definition):
        components = []
        for member in species:
            if len(member) == 2:
                components.append('{0}!{1}'.format(member[0], member[1]))
            else:
                components.append('{0}'.format(member[0]))
        molecules.append('{0}({1})'.format(tag,",".join(components)))
    return ".".join(molecules)

def issubset(possible_sub, superset):
    return all(element in superset for element in possible_sub)



def getFreeRadical(element,rawDatabase,synthesisDatabase,product):
    """
    this method is used when the user does not provide a full binding specification
    it searches a molecule for a component that has not been used before in another reaction
    in case it cannot find one it returns an empty list
    """
    if element not in rawDatabase:
        return []
    components = copy(rawDatabase[element][0])
    for member in synthesisDatabase:
        ##the last condition issubset is in there because knowing that S1 + s2 -> s1.s2 
        #does not preclude s2 from using the same bnding site in s1.s3 + s2 -> s1.s2.s3
        if element[0] in member and not issubset(member,product):
            index = member.index(element[0])
            for temp in [x for x in synthesisDatabase[member][index] if len(x) > 1]:
                if (temp[0],) in components:
                    components.remove((temp[0],))
    if not components:
        return []
    return components[0]

def findIntersection(set1,set2,database):
    """
    this method receives a list of components and returns an element from the database
    that is a subset of the union of both sets
    """
    intersections = []
    for element in [x for x in database.keys() if len(x) > 1]:
        intersection1 = [x for x in element if x in set1]
        intersection2 = [x for x in element if x in set2]
        notInEither = [x for x in element if x not in set1 and x not in set2]
        if len(intersection1)>0 and len(intersection2)>0 and len(notInEither) == 0:
            intersections.append(element)
            
    return intersections
    
def synthesis(original,dictionary,rawDatabase,synthesisDatabase,translator):
    #reaction = []
    for elements in original:
        #temp = []
        for sbml_name in elements:
            ## If we have translated it before and its in mem   ory
 #           if molecule in translator:
 #               species.append(translator[molecule])
 #           else:
                tags,molecules = findCorrespondence(original[0],original[1],dictionary,sbml_name,rawDatabase,synthesisDatabase,translator)
                
                if (tags,molecules) == (None,None):
                    tmp = st.Species()
                    tmp.addMolecule(st.Molecule(sbml_name))
                    translator[sbml_name] = tmp
                    libsbml2bngl.log['reactions'].append(original)
                    print "couldn't process reaction:",original
                #TODO: probably we will need to add a check if there are several ways of defining a reaction
                else:
                    tags = list(tags)
                    tags.sort()
                    tags = tuple(tags)
                    
                    species = st.Species()
                    species.addChunk(tags,molecules)
                    translator[sbml_name] = species
                    if tags not in synthesisDatabase and tags not in rawDatabase:
                        synthesisDatabase[tags] = tuple(molecules)
        #reaction.append(temp)
    #return reaction

def addSiteComponent():
    pass

def getIntersection(reactants,product,dictionary,rawDatabase,synthesisDatabase):
    '''
    this method goes through two complexes and tries to check how they
    get together to create a product (e.g. how their components link)
    either by using previous knowledge or by creating a new complex
    '''
    #global log
    extended1 = (copy(dictionary[reactants[0]]))
    extended2 = (copy(dictionary[reactants[1]]))
    if isinstance(extended1,str):
        extended1 = (extended1,)
    if isinstance(extended2,str):
        extended2 = (extended2,)
    #if we can find an element in the database that is a subset of 
    #union(extended1,extended2) we take it
    intersection = findIntersection(extended1,extended2,synthesisDatabase)
    #otherwise we create it from scratch
    if not intersection:
        r1 = getFreeRadical(extended1,rawDatabase,synthesisDatabase,product)
        r2 = getFreeRadical(extended2,rawDatabase,synthesisDatabase,product)
        if not r1 or not r2:
            #print 'Cannot infer how',extended1,'binds to',extended2
            #log['reactions'].append((reactants,product))
            #return None,None,None
            #TODO this section should be activated by a flag instead
            #of being accessed by default
            createIntersection((extended1[0],extended2[0]),rawDatabase,dictionary)
            r1 = getFreeRadical(extended1,rawDatabase,synthesisDatabase,product)
            r2 = getFreeRadical(extended2,rawDatabase,synthesisDatabase,product)
            if not r1 or not r2:
                return (None,None,None)
        ##todo: modify code to allow for carry over free radicals
        d1 = copy(rawDatabase[extended1][0]) if extended1 in rawDatabase else copy(synthesisDatabase[extended1][0])
        d2 = copy(rawDatabase[extended2][0]) if extended2 in rawDatabase else copy(synthesisDatabase[extended2][0])
        extended1 = list(extended1)
        extended1.extend(extended2)
        rnd = random.randint(0,1000)
        d1.remove(r1)
        d2.remove(r2)
        d1.append((r1[0],rnd))
        d2.append((r2[0],rnd))
        extended1 = [dictionary[x][0] for x in extended1]
        extended1.sort()
        synthesisDatabase[tuple(extended1)] = (d1,d2)
        intersection = (tuple(extended1),)
        extended1 = extended2 = []
        
    return extended1,extended2,intersection

def createIntersection(reactants,rawDatabase,dictionary):
    '''
    if there are no components in record that allow for two species to merge
    we will create those components instead
    '''
    #print 'kakakakakaka',reactants[0],dictionary[reactants[0]]
    #label = dictionary[reactants[0]] if isinstance(dictionary[reactants[0],str) else reactants[0]
    if (reactants[0],) not in rawDatabase:
        rawDatabase[(reactants[0],)] = ([([reactants[1].lower()],)],)
    else:
        temp = rawDatabase[(reactants[0],)][0]
        temp.append(([reactants[1].lower()],))
        rawDatabase[(reactants[0],)] = (temp,)
    #label = dictionary[reactants[1]] if isinstance(dictionary[reactants[1],str) else reactants[1]
    if (reactants[1],) not in rawDatabase:
        rawDatabase[(reactants[1],)] = ([([reactants[0].lower()],)],)
    else:
        temp = rawDatabase[(reactants[1],)][0]
        temp.append(([reactants[0].lower()],))
        rawDatabase[(reactants[1],)] = (temp,)
        
def findCorrespondence(reactants,products,dictionary,sbml_name,rawDatabase,synthesisDatabase,translator):
    """
    this method reconstructs the component structure for a set of sbml
    molecules that undergo synthesis using context and history information    
    """   
    #print reactants,products,dictionary,sbml_name
    #print 'zzz',reactants,products
    species = dictionary[sbml_name]
    if isinstance(species,str):
        species = dictionary[species]
    product = dictionary[products[0]]
    #if the element is already in the synthesisDatabase
    if species in synthesisDatabase:
        return species,synthesisDatabase[species]
    
    elif species in rawDatabase:
        
        #for product in productArray:
        if product in synthesisDatabase:
            temp = [(x[0],) for x in synthesisDatabase[product][product.index(dictionary[species[0]][0])]]
            return species,(temp,)
        return species,rawDatabase[species]
    #this means we are dealing with the basic components rather than the
    #synthetized product

    extended1,extended2,intersection = getIntersection(reactants,product,
                                                       dictionary,rawDatabase,
                                                       synthesisDatabase)
    if len(species) <2:
        return species,rawDatabase[species]
    if (extended1,extended2,intersection) == (None,None,None):
        return None,None
    constructed = [[] for element in species]
    for element in [intersection[0],extended1,extended2]:
        if len(element) > 1:
            for tag,molecule in zip(element,synthesisDatabase[element]):
                #in case we know that one element name is actually another in a special form
                realTag = dictionary[tag][0]
                for member in [x for x in molecule if x not in constructed[species.index(realTag)]]:
                    flag = True
                    for temp in deepcopy(constructed[species.index(realTag)]):
                        if member[0] in temp:
                            if len(member) == 1:
                                flag = False
                            else:
                                constructed[species.index(realTag)].remove(temp)
                    if flag:
                        constructed[species.index(realTag)].append(tuple(member))
    return species,constructed

def creation(original,dictionary,rawDatabase,translator):
    """
    This method deals with reactions of the type 0 -> A
    """
    reaction = [[0],[]]
    reaction[1] = [(tuple(original[1]),rawDatabase[tuple(original[1])],)]
    return reaction

def decay(original,dictionary,rawDatabase,translator):
    """
    This method deals with reactions of the type A -> 0
    """
    reaction = [[],[0]]
    reaction[0] = [(tuple(original[0]),rawDatabase[tuple(original[0])],)]
    return reaction   
    
def getStateName(namingConvention):
    if namingConvention == 'Phosporylation':
        return 'P'
    if namingConvention == 'Double-Phosporylation':
        return 'PP'

def getCatalysisSiteName(namingConvention):
    if namingConvention == 'Phosporylation' or namingConvention == 'Double-Phosporylation':
        return 'phospo'
    

def catalyze(original,modified,namingConvention,rawDatabase,translator):
    result = [0,0]
    if (original,) not in translator:
        result[0] = ([([getCatalysisSiteName(namingConvention),'U'],)],)
        #rawDatabase[(original,)] = ([([getCatalysisSiteName(namingConvention),'U'],)],)
    else:
        if (getCatalysisSiteName(namingConvention),) in rawDatabase[(original,)][0]:
            if not 'U' in rawDatabase[(original,)][1]:
                temp = list(rawDatabase[(original,)])
                #todoL we ave to actually get an index, not blindly append
                temp[1].append(['U'])
                result[0] = tuple(temp)
                #rawDatabase[(original,)] = tuple(temp)
        else:
            temp = list(rawDatabase[(original,)])
            temp[0].append((getCatalysisSiteName(namingConvention),))
            temp[1].append(['U'])
            #rawDatabase[(original,)] = tuple(temp)
            result[0] = tuple(temp)
    if (modified,) not in translator:
        #rawDatabase[(modified,)] = ([([getCatalysisSiteName(namingConvention),getStateName(namingConvention)],)],)
        result[1] = ([([getCatalysisSiteName(namingConvention),getStateName(namingConvention)],)],)
    else:
        if (getCatalysisSiteName(namingConvention),) in rawDatabase[(modified,)][0]:
            if not getStateName(namingConvention) in rawDatabase[(modified,)][1]:
                temp = list(rawDatabase[(modified,)])
                temp[1].append([getStateName(namingConvention)])
                #rawDatabase[(modified,)] = tuple(temp)
                result[1] = tuple(temp)
        else:
            temp = list(rawDatabase[(modified,)]) 
            temp[0].append((getCatalysisSiteName(namingConvention),))
            temp[1].append([getStateName(namingConvention)])
            #rawDatabase[(modified,)] = tuple(temp)
            result[1] = temp
    return result
            
def catalysis(original,dictionary,rawDatabase,catalysisDatabase,translator,
              namingConvention,classification):
    """
    This method is for reactions of the form A+ B -> A' + B
    """
    result = catalyze(namingConvention[0],namingConvention[1],classification,rawDatabase
    ,translator)
    if namingConvention[0] not in translator:
        species = st.Species()
        species.addChunk([namingConvention[0]],result[0])
        translator[namingConvention[0]] = species
    species = st.Species()
    species.addChunk([namingConvention[0]],result[1])
    translator[namingConvention[1]] = species