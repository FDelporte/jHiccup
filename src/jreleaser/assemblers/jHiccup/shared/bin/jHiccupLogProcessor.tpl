#!/bin/bash
#
# jHiccupLogProcessor
#
# Written by Gil Tene, and released to the public domain, as explained at
#  http://creativecommons.org/publicdomain/zero/1.0/
#
JHICCUP_Version={{projectVersion}}
#
# jHiccupLogProcessor will process an input log and can generate two
# different log files from a single jHiccup histogram log file: a
# sequential interval log file and a histogram log file.
#
# The sequential interval log file logs a single %'ile stats line for
# each reporting interval.
#
# The histogram percentile log file includes a detailed %'ile histogram
# of the entire log file range.
#
# jHiccupLogProcessor will process an input log file when provided with
# the -i <filename> option. When no -i option is provided, standard input
# will be processed.
#
# When provided with an output file name <logfile> with the -o option
# (e.g. "-o mylog"), jHiccupLogProcessor will produce both output files
# under the names <logfile> and <logfile>.hgrm (e.g. mylog and mylog.hgrm).
#
# When not provided with an output file name, jHiccupLogProcessor will
# produce [only] the histogram percentile log output to standard output.
#
# jHiccupLogProcessor accepts optional -start and -end time range
# parameters. When provided, the output will only reflect the portion
# of the input log with timestamps that fall within the provided start
# and end time range parameters.
#
# jHiccupLogProcessor also accepts and optional -csv parameter, which
# will cause the output formatting (of both output file forms) to use
# a CSV file format.
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

JAVA_BIN=`which java`

if [ $JAVA_HOME ]; then
    JAVA_CMD=$JAVA_HOME/bin/java
elif [ $JAVA_BIN ]; then
    JAVA_CMD=$JAVA_BIN
else
    echo "For this command to run, either $JAVA_HOME must be set, or java must be in the path."
    exit 1
fi

#
# Parse original java execution arguments:
#
# At this point, we should have valid $PARSED_BinJava, $PARSED_JavaArgs, $PARSED_AppArgs:
#echo PARSED_BinJava = "$PARSED_BinJava"
#echo PARSED_JavaArgs = "$PARSED_JavaArgs"
#echo PARSED_AppArgs = "$PARSED_AppArgs"

# Deal with Windows/cygwin path normalization syntax needs:
# Key Assumption: only cygwin/Windows installations will have a cygpath command...
cygpath -w $JHICCUP_JAR_FILE &> /dev/null
if [ $? -eq 0 ] ; then
    # if using cygwin, use valid windows-style classpath
    JHICCUP_JAR_FILE=`cygpath -w $JHICCUP_JAR_FILE`
	echo Windows path for hiccup jar file is $JHICCUP_JAR_FILE
fi

exec $JAVA_CMD -cp $JHICCUP_JAR_FILE org.jhiccup.internal.hdrhistogram.HistogramLogProcessor $@
#exec $CMD
