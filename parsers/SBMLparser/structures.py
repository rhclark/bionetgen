# -*- coding: utf-8 -*-
"""
Created on Wed May 30 11:44:17 2012

@author: proto
"""

class Species:
    def __init__(self):
        self.molecules = []
        
    def addMolecule(self,molecule):
        self.molecules.append(molecule)
        
    def getSize(self):
        return len(self.molecules)
        
    def addChunk(self,tags,moleculesComponents):
        '''
        temporary transitional method
        '''
        for (tag,components) in zip (tags,moleculesComponents):
            tmp = Molecule(tag)
            for component in components:
                tmpCompo = Component(component[0][0])
                for index in range(1,len(component[0])):
                    tmpCompo.addState(component[0][index])
                if len(component) > 1:
                    tmpCompo.addBond(component[1])
                tmp.addComponent(tmpCompo)
            self.molecules.append(tmp)
    def __str__(self):
        return '.'.join([x.toString() for x in self.molecules])
        
    def toString(self):
        return self.__str__()
        

class Molecule:
    def __init__(self,name):
        self.components = []
        self.name = name
        
    def addComponent(self,component):
        self.components.append(component)
        
    def getComponent(self,componentName):
        for component in self.components:
            if componentName == component.getName():
                return component
                
    def addBond(self,componentName,bondName):
        component = self.getComponent(componentName)
        component.addBond(bondName)
        
            
    def __str__(self):
        return self.name + '(' + ','.join([str(x) for x in self.components]) + ')'
        
    def toString(self):
        return self.__str__()
    
class Component:
    def __init__(self,name,bonds = [],states=[]):
        self.name = name
        self.states = states
        self.bonds = []
        self.activeState = ''
        
    def addState(self,state):
        self.states.append(state)
        self.setActiveState(state)
        
    def addBond(self,bondName):
        self.bonds.append(bondName)
        
    def setActiveState(self,state):
        if state not in self.states:
            return False
        self.activeState = state
        return True
        
    def getRuleStr(self):
        tmp = self.name
        if len(self.bonds) > 0:
            tmp += '!' + '!'.join([str(x) for x in self.bonds])
        if self.activeState != '':
            tmp += '~' + self.activeState
        return tmp
        
    def getTotalStr(self):
        return self.name + '~'.join(self.states)
    
    def getName(self):
        return self.name 
        
    def __str__(self):
        return self.getRuleStr()
        
        
class Databases:
    def __init__(self):
        self.translator ={}
        self.synthesisDatabase = {}
        self.catalysisDatabase = {}
        self.rawDatabase = {}
        self.labelDictionary = {}
        
    def getRawDatabase(self):
        return self.rawDatabase
        
    def getLabelDictionary(self):
        return self.labelDictionary
        
    def add2LabelDictionary(self,key,value):
        temp = tuple(key)
        temp = temp.sort()
        self.labelDictionary[temp] = value

    def add2RawDatabase(self,rawDatabase):
        pass
    
    def getTranslator(self):
        return self.translator
    