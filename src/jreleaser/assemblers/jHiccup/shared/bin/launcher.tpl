#!/bin/bash
#
# jHiccup
#
# Written by Gil Tene, and released to the public domain, as explained at
#  http://creativecommons.org/publicdomain/zero/1.0/
#
JHICCUP_Version={{projectVersion}}
#
# jHiccup is a platform pause measurement tool, it is meant to observe the
# underlying platform (JVM, OS, HW, etc.) responsiveness while under an
# unrelated application load, and establish a lower bound for the stalls
# the application would experience. It is run as a wrapper around
# other applications so that measurements can be done without any changes
# to application code.
#
# The purpose of jHiccup is to aid application operators and testers in
# characterizing the inherent "platform hiccups" (execution stalls)
# that a Java platform will display when running under load. The hiccups
# measured are NOT stalls caused by the application's code. They are stalls
# caused by the platform (JVM, OS, HW, etc.) that would be visible to and
# affect any application thread running on the platform at the time of the
# stall.It is generally safe to assume that if jHiccup experiences and
# records a certain level of measured platform hiccups, the application
# running on the same JVM platform during that time had experienced
# hiccup/stall effects that are at least as large as the measured level.
#
# jHiccup's measurement works on the simple basis of measuring the time it
# takes an effectively empty workload to perform work (while running alongside
# whatever load the platform is carrying). Hiccup measurements are performed
# by a thread that repeatedly sleeps for a given interval (-r for resolutionMs,
# defaults to 1 msec), and logs the amount of time it took to actually wake up
# each time in a  detailed internal hiccup histogram. The assumption is that
# if the measuring thread experienced some delay in waking up, any other thread
# in the system could/would have experienced a similar delay, resulting in
# application stalls.
#
# jHiccup produces a single log file (hiccup.YYMMDD.HHMM.pid.hlog) in Histogram
# log format (see HdrHistogram documentaton for HistogramLogReader for details).
# This log file captures histograms for each logging interval (set
# with -i <reportingIntervalMs>, defaults to 5000 msec)., which can later
# be processed to reconstruct hiccup behavior over an arbitrary portion of the
# log. The -l <logname> can be used to override the log file name.
#
# An associated utlity, jHiccupLogProcessor, generates two log files from this
# log file: a sequential interval log file and a histogram log file.
# The sequential interval log file logs a single %'ile stats line for each
# reporting interval. The histogram log file includes a detailed %'ile histogram
# of the run so far.
# See documentation or help for jHiccupLogProcessor for details.
#
#
# jHiccup can be configured to delay the start of measurement
# (using the -d <startDelayMs> flag, defaults to 0 msec).
#
# jHiccup will continue to run until the application it is wrapping exists.
#
# Using the -c option (off by default), jHiccup can be configured to launch
# a concurrently executing "control process" that will separately log hiccup
# information of an idle workload running on a separate jvm for the duration
# of the instrumented application run. When selected, the control process log
# file name will match the one used for the preceded application, preceded
# with a "c.".
#
# For convenience in testing, jHiccup can be executed as a simple wrapper for
# java program execution. All it takes is adding the word "jHiccup" in front
# of whatever the java invocation command line is.
#
# For example, if your program were normally executed as:
#
# java <Java args> UsefulProgram -a -b -c
#
# The launch line would become:
#
# jHiccup java <Java args> UsefulProgram -a -b -c
#
# or, for a program that is launch like this:
#
# /usr/bin/java <Java args> -jar UsefulProgram.jar -a -b -c
#
# The launch line would become:
#
# jHiccup /usr/bin/java <Java args> -jar UsefulProgram.jar -a -b -c
#
# or, to override the defaults by making the recording start delay 60 seconds
# and log to hlog, it would become:
#
# jHiccup -d 60000 -l hlog /usr/bin/java <Java args> -jar UsefulProgram.jar -a -b -c
#

# Attempt to set APP_HOME
# Resolve links: $0 may be a link
PRG="$0"
# Need this for relative symlinks.
while [ -h "$PRG" ] ; do
    ls=`ls -ld "$PRG"`
    link=`expr "$ls" : '.*-> \(.*\)$'`
    if expr "$link" : '/.*' > /dev/null; then
        PRG="$link"
    else
        PRG=`dirname "$PRG"`"/$link"
    fi
done
SAVED="`pwd`"
cd "`dirname \"$PRG\"`/.." >/dev/null
APP_HOME="`pwd -P`"
cd "$SAVED" >/dev/null

JHICCUP_JAR_FILE=$APP_HOME/lib/jHiccup.jar

DATE=`date +%y%m%d.%H%M`

#
# Parse original java execution arguments:
#
count=0
JHiccupArgs=
readingJHiccupArgs=0
PARSED_BinJava=
readingJavaBin=1
readingJavaArgs=0
PARSED_JavaArgs=
PARSED_AppArgs=
for var in $@; do
#	echo $count: "$var"
	if [ $readingJavaBin -eq 1 ] ; then
		# Looking for JavaBin. Identify and parse jHiccup args
		if [ $readingJHiccupArgs -eq 1 ]; then
			# This was marked as an arg to jHiccup
			JHiccupArgs="$JHiccupArgs $var"
			readingJHiccupArgs=0
		elif [ $var = "-v" ]; then
			# -v is a flag arg to jHiccup
			JHiccupArgs="$JHiccupArgs $var"
		elif [ $var = "-0" ]; then
            # -0 is a flag arg to jHiccup
            JHiccupArgs="$JHiccupArgs $var"
		elif [ $var = "-c" ]; then
			# -c is a flag arg to jHiccup
			JHiccupArgs="$JHiccupArgs $var"
		elif [ $var = "-o" ]; then
			# -o is a flag arg to jHiccup
			JHiccupArgs="$JHiccupArgs $var"
		elif [ ${var:0:1} = "-" ]; then
			# This is a parameter arg to jHiccup
			JHiccupArgs="$JHiccupArgs $var"
			readingJHiccupArgs=1
		else
			# Found JavaBin
			PARSED_BinJava="$var"
			readingJavaBin=0
			readingJavaArgs=1
		fi
	elif [ $readingJavaArgs -eq 1 ]; then
		# Parsing Java args
		if [ ${var:0:1} = "-" ]; then
			PARSED_JavaArgs="$PARSED_JavaArgs $var"
		else
			readingJavaArgs=0
			PARSED_AppArgs="$var"
		fi
	else
		# Parsing app args
		PARSED_AppArgs="$PARSED_AppArgs $var"
	fi
	let "count = $count + 1"
done
# At this point, we should have valid $PARSED_BinJava, $PARSED_JavaArgs, $PARSED_AppArgs:
#echo PARSED_BinJava = "$PARSED_BinJava"
#echo PARSED_JavaArgs = "$PARSED_JavaArgs"
#echo PARSED_AppArgs = "$PARSED_AppArgs"

#
# Parse jHiccup arguments:
#
JHICCUP_DelayArg=
readingDelayArg=0
JHICCUP_RunTimeArg=
readingRunTimeArg=0
JHICCUP_IntervalArg=
readingIntervalArg=0
JHICCUP_ResolutionArg=
readingResolutionArg=0
JHICCUP_LognameArg=
readingLognnameArg=0
JHICCUP_PidOfProcessToAttacheToArg=
readingPidOfProcessToAttacheToArg=0

verboseOutput=
logFormatCsv=
startTimeAtZero=
JHiccupArgs_parse_error=
JHICCUP_ControlProcessFlag=

for var in $JHiccupArgs; do
	if [ $readingDelayArg -eq 1 ]; then
		JHICCUP_DelayArg=$var
		readingDelayArg=0
	elif [ $readingRunTimeArg -eq 1 ]; then
        JHICCUP_RunTimeArg=$var
        readingRunTimeArg=0
	elif [ $readingIntervalArg -eq 1 ]; then
		JHICCUP_IntervalArg=$var
		readingIntervalArg=0
	elif [ $readingResolutionArg -eq 1 ]; then
		JHICCUP_ResolutionArg=$var
		readingResolutionArg=0
	elif [ $readingLognnameArg -eq 1 ]; then
		JHICCUP_LognameArg=$var
		readingLognnameArg=0
	elif [ $readingPidOfProcessToAttacheToArg -eq 1 ]; then
        JHICCUP_PidOfProcessToAttacheToArg=$var
        readingPidOfProcessToAttacheToArg=0
	elif [ $var = "-d" ]; then
		readingDelayArg=1
	elif [ $var = "-t" ]; then
        readingRunTimeArg=1
	elif [ $var = "-i" ]; then
		readingIntervalArg=1
	elif [ $var = "-r" ]; then
		readingResolutionArg=1
	elif [ $var = "-l" ]; then
		readingLognnameArg=1
	elif [ $var = "-p" ]; then
        readingPidOfProcessToAttacheToArg=1
	elif [ $var = "-c" ]; then
		JHICCUP_ControlProcessFlag=1
	elif [ $var = "-0" ]; then
		startTimeAtZero=1
	elif [ $var = "-o" ]; then
		logFormatCsv=1
    elif [ $var = "-v" ]; then
		verboseOutput=1
		echo jHiccup version $JHICCUP_Version
	else
	    JHiccupArgs_parse_error=1
	fi
done

if [ $readingDelayArg -eq 1 ]; then
    JHiccupArgs_parse_error=1
elif [ $readingRunTimeArg -eq 1 ]; then
    JHiccupArgs_parse_error=1
elif [ $readingIntervalArg -eq 1 ]; then
    JHiccupArgs_parse_error=1
elif [ $readingResolutionArg -eq 1 ]; then
    JHiccupArgs_parse_error=1
elif [ $readingLognnameArg -eq 1 ]; then
    JHiccupArgs_parse_error=1
elif [ $readingPidOfProcessToAttacheToArg -eq 1 ]; then
    JHiccupArgs_parse_error=1
fi

# Should not have both a java command and a -p option:
if [ $PARSED_BinJava ]; then
    if [ $JHICCUP_PidOfProcessToAttacheToArg ]; then
        JHiccupArgs_parse_error=1
    fi
fi

if [ $JHiccupArgs_parse_error ]; then
		echo $PARSED_SCRIPT $@
		echo jHiccup version $JHICCUP_Version
		echo "Usage:"
		echo "  jHiccup [-d startupDelayMsec] [-t runTimeMsec] [-i recordingIntervalMsec] [-l logname]"
		echo "               [-r sampleResolutionMsec] [-c] [-p pidOfProcessToAttachTo]"
		echo "  or:"
		echo "  jHiccup [-d startupDelayMsec] [-t runTimeMsec] [-i recordingIntervalMsec] [-l logname]"
        echo "               [-r sampleResolutionMsec] [-c] <java command line>"
		echo "Where:"
		echo " -l logname                Sets the log files to <logname> and <logname>.hgrm"
		echo "                           (default <logname> is \"hiccup.yymmdd.hhmm.pid\") "
		echo "                           (replaces occurrences of %pid and %date with appropriate info)"
		echo " -o                        Output log files in CSV format"
		echo " -c                        Concurrently start a control process to record hiccups"
		echo "                           experienced by an Idle load running on a separate jvm"
		echo "                           in log files <logname>.c and <logname>.c.hgrm"
		echo " -p pidOfProcessToAttachTo Attach to the process with given pid and inject jHiccup as an agent"
		echo "                           (no default)"
		echo " -d startupDelayMsec       Sets the delay, in milliseconds before sampling starts"
		echo "                           (default 0)"
		echo " -t runTimeMsec            Limit measurement and logging time"
        echo "                           (default 0, for infinite)"
		echo " -0                        Start logfile timestamps at 0 (as opposed to JVM uptime at start point)"
		echo "                           (default off)"
		echo " -i recordingIntervalMsec  Sets the reporting interval in milliseconds"
		echo "                           (default 5000)"
		echo " -r sampleResolutionMsec   Sets the sampling resolution in milliseconds"
		echo "                           (default 1)"
		echo " -v                        Verbose output"
		exit -1
fi

JHICCUP_Options=""

if [ $JHICCUP_DelayArg ]; then
	JHICCUP_Options="${JHICCUP_Options}-d $JHICCUP_DelayArg "
fi

if [ $JHICCUP_RunTimeArg ]; then
	JHICCUP_Options="${JHICCUP_Options}-t $JHICCUP_RunTimeArg "
fi

if [ $JHICCUP_IntervalArg ]; then
	JHICCUP_Options="${JHICCUP_Options}-i $JHICCUP_IntervalArg "
fi

if [ $JHICCUP_ResolutionArg ]; then
	JHICCUP_Options="${JHICCUP_Options}-r $JHICCUP_ResolutionArg "
fi

if [ $JHICCUP_LognameArg ]; then
	JHICCUP_Options="${JHICCUP_Options}-l $JHICCUP_LognameArg "
fi

if [ $startTimeAtZero ]; then
	JHICCUP_Options="${JHICCUP_Options}-0 "
fi

if [ $logFormatCsv ]; then
	JHICCUP_Options="${JHICCUP_Options}-o "
fi

if [ $JHICCUP_ControlProcessFlag ]; then
	JHICCUP_Options="${JHICCUP_Options}-c "
fi

if [ $verboseOutput ]; then
	JHICCUP_Options="${JHICCUP_Options}-v "
fi

# Deal with Windows/cygwin path normalization syntax needs:
# Key Assumption: only cygwin/Windows installations will have a cygpath command...
cygpath -w $JHICCUP_JAR_FILE &> /dev/null
if [ $? -eq 0 ] ; then
    # if using cygwin, use valid windows-style classpath
    JHICCUP_JAR_FILE=`cygpath -w $JHICCUP_JAR_FILE`
	echo Windows path for hiccup jar file is $JHICCUP_JAR_FILE
fi

if [ $JHICCUP_PidOfProcessToAttacheToArg ]; then
	JHICCUP_Options="${JHICCUP_Options}-j $JHICCUP_JAR_FILE -p $JHICCUP_PidOfProcessToAttacheToArg "

	#
    # Prepare and execute attach command:
    #

	CMD="$JAVA_HOME/bin/java -cp $JAVA_HOME/lib/tools.jar:$JHICCUP_JAR_FILE org.jhiccup.HiccupMeterAttacher $JHICCUP_Options"
    if [ $verboseOutput ]; then
    	echo jHiccup executing: $CMD
    fi
	exec $JAVA_HOME/bin/java -cp $JAVA_HOME/lib/tools.jar:$JHICCUP_JAR_FILE org.jhiccup.HiccupMeterAttacher $JHICCUP_Options
fi

#
# Prepare and execute command:
#
CMD="$PARSED_BinJava -javaagent:$JHICCUP_JAR_FILE=\"$JHICCUP_Options\" $PARSED_JavaArgs $PARSED_AppArgs"
if [ $verboseOutput ]; then
	echo jHiccup executing: $CMD
fi
exec $PARSED_BinJava -javaagent:$JHICCUP_JAR_FILE="$JHICCUP_Options" $PARSED_JavaArgs $PARSED_AppArgs
#exec $CMD
