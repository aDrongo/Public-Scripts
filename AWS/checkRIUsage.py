#Need to install AWS CLI and run aws configure first
#Need to pip install pandas and openpyxl

import boto3
import datetime
import pandas

class Instance:
    id = ""
    name = ""
    ec2type = ""
    platform = ""
    reserved = False

    def __init__(self,id,ec2type):
        self.id = id
        self.ec2type = ec2type
    
    def addName(self,name):
        self.name = name
    
    def addPlatform(self,platform):
        self.platform = platform
    
    def __repr__(self):
        return f"{self.name}"

class Reservation:
    ec2type = ""
    platform = ""
    reserved = False

    def __init__(self, ec2type, platform):
        self.ec2type = ec2type
        self.platform = platform

class ReservationUsage:
    instances = []
    reservations = []

    def __init__(self):
        self.getReservations()
        self.getInstances()
    
    def getReservations(self):
        ec2 = boto3.client('ec2')
        prelim_reservations = ec2.describe_reserved_instances()['ReservedInstances']
        for reservation in prelim_reservations:
            if reservation['State'] == 'active':
                count = int(reservation['InstanceCount'])
                for i in range(count):
                    newReservation = Reservation(reservation['InstanceType'],reservation['ProductDescription'])
                    self.reservations.append(newReservation)
    
    def getInstances(self):
        ec2 = boto3.client('ec2')
        ec2Instances = ec2.describe_instances()['Reservations']
        for instance in ec2Instances:
            instanceDetails = instance['Instances'][0]
            if instanceDetails['State']['Name'] == 'running':
                newInstance = Instance(instanceDetails['InstanceId'],instanceDetails['InstanceType'])
                newInstance.addName(self._getTag(instanceDetails['Tags'], 'Name'))
                newInstance.addPlatform(self._getTag(instanceDetails['Tags'], 'Platform'))
                self.instances.append(newInstance)

    def _getTag(self, tags, key):
            for tag in tags:
                if tag.get('Key') == key:
                    return tag['Value']
            return "None"
    
    def getUsedAndReserved(self):
        for reservation in self.reservations:
            for instance in self.instances:
                if (instance.reserved != True and 
                                                instance.ec2type == reservation.ec2type and 
                                                instance.platform in reservation.platform):
                    instance.reserved = True
                    reservation.reserved = True
                    break

    def exportReservedExcel(self):
        exportList = []
        for reserve in self.reservations:
            exportList.append(dict(Type = reserve.ec2type,
                                    Platform = reserve.platform,
                                    Reserved = reserve.reserved))
        df = pandas.DataFrame(exportList)
        df.to_excel(r'Reserved.xlsx')


    def exportInstancesExcel(self):
        exportList = []
        for instance in self.instances:
            exportList.append(dict(Name = instance.name,
                                    Type = instance.ec2type,
                                    Platform = instance.platform,
                                    Reserved = instance.reserved))
        df = pandas.DataFrame(exportList)
        df.to_excel(r'Instances.xlsx')
        
    
if __name__ == "__main__":
    reserveUsage = ReservationUsage()
    reserveUsage.getUsedAndReserved()
    reserveUsage.exportReservedExcel()
    reserveUsage.exportInstancesExcel()
