import os,sys,string,datetime
import ktl
import argparse
from subprocess import Popen,PIPE, call

import smtplib
from email.MIMEMultipart import MIMEMultipart
from email.MIMEText import MIMEText

def sendEmailLocal(From,To,Subject,Body):
    fromaddr = From
    toaddr = To
    msg = MIMEMultipart("alternative")
    msg['From'] = fromaddr
    msg['To'] = toaddr
    msg['Subject'] = Subject

    body = Body
    msg.attach(MIMEText(body, 'plain'))
    p = Popen(['/usr/sbin/sendmail','-t'], stdin=PIPE)
    p.communicate(msg.as_string())


 
def sendEmail(From,To,Subject,Body, Password):
    fromaddr = From
    toaddr = To
    msg = MIMEMultipart()
    msg['From'] = fromaddr
    msg['To'] = toaddr
    msg['Subject'] = Subject
 
    body = Body
    msg.attach(MIMEText(body, 'plain'))
 
    server = smtplib.SMTP('smtp.gmail.com', 587)
    server.starttls()
    server.login(fromaddr,Password)
    text = msg.as_string()
    server.sendmail(fromaddr, toaddr, text)
    server.quit()



class AlarmHandler():

    def __init__(self,type):
        # available type so far are temperature, pressure, alive
        # temperature
        # pressure
        # alive: check that a service is alive
        # keyword range: check that a keyword is within a range

        self.debug=False

        self.debugMessage("Starting alarm initialization")
        self.type=type
        self.dateFormat = " %Y-%m-%d %H:%M:%S.%f"
        self.keywordDateFormat = ""
        self.serviceNotRunning={}
        self.alarmsDisabled={}
        self.missingValue={}
        self.raiseAlarm={}
        self.remedialAction = None

    def debugMessage(self,comment):
        if self.debug==True:
            sys.stdout.write(comment+"\n")


    def setLogInfo(self, logDir, logFileName, statusFileName):
        self.debugMessage("Checking log directory and file name")
        # check if the log directory exists and attempt to create it if not
        if (os.path.isdir(logDir) is False):
            try:
                os.mkdir(logDir)
            except:
                sys.stdout.write("The log directory does not exist and cannot be created\n")
                sys.exit(1)
        
        self.logDir = logDir
        self.logFileName = os.path.join(logDir,logFileName)
        self.statusFileName = os.path.join(logDir,statusFileName)

    def setAndCheckService(self,library):
        try:
            self.debugMessage("Attempting to connect to the KTL service %s." % (library))
            self.service = ktl.cache(library)
        except:
           self.debugMessage("Failed to connect to service %s." % (library))
           self.debugMessage("Sending out email to %s." % (self.whoInfo))
           body = self.serviceNotRunning['body']
           subject = self.serviceNotRunning['subject']
           sendEmailLocal(self.whoFrom,self.whoInfo,subject,body)
           sys.exit(1)

    def readStatusFile(self):
        self.record={}
        self.debugMessage("Checking existance of status file %s" % (self.statusFileName))
        if (os.path.isfile(self.statusFileName)):
            self.debugMessage("The file exists.")
            with open(self.statusFileName) as f:
               for line in f:
                   key,value = line.split('=')
                   value=string.replace(value,'\n','')
                   self.record[key]=value

    def writeStatusFile(self):
        f = open(self.statusFileName,'w')
        for key in self.record.keys():
            f.write(key+'= '+str(self.record[key])+'\n')
        f.close()

    def writeLogFile(self, string):
        self.debugMessage("Attempting to write to %s." % (self.logFileName))
        f = open(self.logFileName,'a')
        f.write(string)
        f.close()

    def action(self,action,minutes):
        self.action=action
        self.readStatusFile()
        self.debugMessage("Processing action request %s" % (self.action))
        # disable
        if (self.action == 'disable'):
            self.debugMessage("Disable requested")
            self.record['disable']=self.timeNow()
            self.record['reminder']=self.timeNow()
            self.writeStatusFile()
            sys.stdout.write("Alarm is now disabled\n")
            sys.exit(0)
        # enable
        elif (self.action == 'enable'):
            self.debugMessage("Enable requested")
            if 'disable' in self.record.keys():
                self.debugMessage("Removing 'disable' status")
                del self.record['disable']
            if 'snooze' in self.record.keys():
                self.debugMessage("Removing 'snooze' status")
                del self.record['snooze']
            self.writeStatusFile()
            sys.stdout.write("Alarm is now re-enabled.\n")
            sys.exit(0)
        elif (self.action == 'snooze'):
            self.debugMessage("Snooze requested")
            self.record['snooze']=self.timeNow()+datetime.timedelta(minutes=int(minutes))
            self.writeStatusFile()
            sys.exit(0)
        elif (self.action == 'status'):
            pass

    def checkSnoozing(self):
        self.debugMessage("Check for snoozing...")

        if 'snooze' in self.record.keys():
            
            # if the current time is before the snooze end time, do nothing
            timeNow = self.timeNow()
            timeRecord = self.timeRecord(self.record['snooze'])
            if timeNow<timeRecord:
                sys.stdout.write("Alarm is snoozing until %s\n" % (str(timeNow)))
                sys.exit(0)
                return True
            else:
                self.debugMessage("Alarm is not snoozing")
                return False

    def checkDisabled(self):
        self.debugMessage("Check for disabled...")

        if 'disable' in self.record.keys():
            # alarm is disabled
            timeNow = self.timeNow()
            timeRecord = self.timeRecord(self.record['reminder'])
            sys.stdout.write("Alarm is disabled.\n")
            if (timeNow>timeRecord+datetime.timedelta(days=1)):
                sys.stdout.write("Alarm has been disabled for more than 1 day\n")
                self.record['reminder']=self.timeNow()
                self.writeStatusFile()
                body = self.alarmsDisabled['body']
                subject = self.alarmsDisabled['subject']
                sendEmailLocal(self.whoFrom,self.whoInfo,subject,body)
            
            sys.exit(0)

    def mainCheck(self):
        # can we access the keyword?
        try:
            self.debugMessage("Attempting to access keyword %s." % (self.valueKeyword))
            value = self.service[self.valueKeyword].read()
        except:
            sys.stdout.write("Cannot access "+self.valueKeyword+" Keyword\n")
            # We cannot access the keyword. Check how long it has been
            self.debugMessage("Checking for last good value")
            if 'last_good' not in self.record.keys():
                self.debugMessage("Last good value not recorded in status file. Assuming that the last good value is now.")
                self.debugMessage("this will invalidate this check and the alarm needs to be run again")
                self.record['last_good']=datetime.datetime.strftime(self.timeNow(),self.dateFormat)
                self.writeStatusFile()
            dateTimeSinceLastAction = self.timeNow()-self.timeRecord(self.record['last_good'])
            minutesSinceLastAction = int(dateTimeSinceLastAction.total_seconds()/60)

            if (minutesSinceLastAction > self.maxDelay):
                sys.stdout.write("WARNING: no monitored keyword value for "+str(minutesSinceLastAction)+" minutes.\n")
                body = self.missingValue['body']
                body = body + """
                
                The last good reading was at """+str(self.timeRecord(self.record['last_good']))

                subject = self.missingValue['subject']
                sendEmailLocal(self.whoFrom,self.whoWarning,subject,body)
                sys.exit(1)

        if (self.type in ['temperature','pressure', 'range']):
            self.debugMessage("This is an instance of %s alarm." % (self.type))
            self.debugMessage("the value returned by the server is %s" % (value))
            try:
                value=float(value)
                # if this is a temperature alarm, and the units are C, then subtract 273.15
                if self.type == 'temperature' and self.units == 'C':
                    value = value - 273.15
            except:
                sys.stdout.write("Error: the server returned a value of %s which is not a float" % (str(value)))
                sys.exit(1)
            
            self.debugMessage("Checking if value is within range: %s < %s < %s" % (str(self.minValue),str(value),str(self.maxValue)))
            if (value>=self.minValue and value<=self.maxValue):
                sys.stdout.write("All good\n")
                self.debugMessage("Updating last good record in status file")
                self.record['last_good']=self.timeNow()
                self.writeStatusFile()
                sys.exit(0)
            else:
                sys.stdout.write("WARNING: Keyword is out of range\n")

                # if a remedial action is defined, trigger it

                if self.remedialAction is not None:
                    call(self.remedialAction)
                    
                body = self.raiseAlarm['body']
                body = body + """
            
                The current  value of """+self.valueKeyword+""" is """+str(value)+"""

                The expected value of """+self.valueKeyword+""" is """+str(self.targetValue) 

                subject = self.raiseAlarm['subject']
                sendEmailLocal(self.whoFrom,self.whoWarning,subject,body)
                self.writeLogFile(str(self.timeNow())+" "+self.tkloggerString+" "+str(value)+"\n")
                sys.exit(1)
        if (self.type == 'alive'):
            self.debugMessage("This is an instance of %s alarm." % (self.type))
            self.debugMessage("the value returned by the server is %s" % (value))

            maxTimeDifference = 5 # (in minutes)
            lastAlive = datetime.datetime.strptime(value,self.keywordDateFormat)
            timeNow = self.timeNow()
            secondsDifference = lastAlive-timeNow
            minutesDifference = abs(secondsDifference.total_seconds()/60)
            self.debugMessage("Lastalive and the current time differ by %s minutes" % (str(minutesDifference)))
            if minutesDifference > maxTimeDifference:
                sys.stdout.write("WARNING: Lastalive is out of range\n")
                self.debugMessage("Last alive: %s " % (str(lastAlive)))
                self.debugMessage("time now:   %s " % (str(timeNow)))
                body = self.raiseAlarm['body']
                body = body + """
            
                The current  value of """+self.valueKeyword+""" is """+str(value)+"""

                The expected value of """+self.valueKeyword+""" is """+str(self.targetValue) 

                subject = self.raiseAlarm['subject']
                sendEmailLocal(self.whoFrom,self.whoWarning,subject,body)
                self.writeLogFile(str(self.timeNow())+" "+self.tkloggerString+" "+str(value)+"\n")
                sys.exit(1)
            else:
                sys.stdout.write("All good\n")

    def timeNow(self):
        return datetime.datetime.now()
    def timeRecord(self,string):
        return datetime.datetime.strptime(string,self.dateFormat)


    def checkStatus(self):
        self.readStatusFile()
        self.checkSnoozing()
        self.checkDisabled()

        
