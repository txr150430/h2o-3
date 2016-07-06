#!/bin/bash

# Clean out any old sandbox, make a new one
OUTDIR=sandbox
rm -fr $OUTDIR; mkdir -p $OUTDIR

# Check for os
SEP=:
case "`uname`" in
    CYGWIN* )
      SEP=";"
      ;;
esac

function cleanup () {
  kill -9 ${PID_1} ${PID_2} ${PID_3} ${PID_4} 1> /dev/null 2>&1
  wait 1> /dev/null 2>&1
}

function testOutput() {
  tshark -r h2o-nonSSL.pcap -Tfields -e data

  # check it contains data from smalldata/gbm_test/Mfgdata_gaussian_GBM_testing.csv

  tshark -r h2o-SSL.pcap -Tfields -e data

  # check it doesn't contain data from smalldata/gbm_test/Mfgdata_gaussian_GBM_testing.csv

  #RC=`cat $OUTDIR/status.0`
  RC=0
  if [ $RC -ne 0 ]; then
    cat $OUTDIR/out.0
    echo h2o-algos junit tests FAILED
  else
    echo h2o-algos junit tests PASSED
  fi
  exit $RC
}

trap cleanup SIGTERM SIGINT

# Find java command
if [ -z "$TEST_JAVA_HOME" ]; then
  # Use default
  JAVA_CMD="java"
else
  # Use test java home
  JAVA_CMD="$TEST_JAVA_HOME/bin/java"
  # Increase XMX since JAVA_HOME can point to java6
  JAVA6_REGEXP=".*1\.6.*"
  if [[ $TEST_JAVA_HOME =~ $JAVA6_REGEXP ]]; then
    JAVA_CMD="${JAVA_CMD}"
  fi
fi

JVM="nice $JAVA_CMD -ea -Xmx3g -Xms3g -cp build/libs/h2o-algos-test.jar${SEP}build/libs/h2o-algos.jar${SEP}../h2o-core/build/libs/h2o-core-test.jar${SEP}../h2o-core/build/libs/h2o-core.jar${SEP}../h2o-genmodel/build/libs/h2o-genmodel.jar${SEP}../lib/*"
echo "$JVM" > $OUTDIR/jvm_cmd.txt

SSL=""
# Launch 3 helper JVMs.  All output redir'd at the OS level to sandbox files.
CLUSTER_NAME=junit_cluster_$$
CLUSTER_BASEPORT=44000
$JVM water.H2O -name $CLUSTER_NAME -baseport $CLUSTER_BASEPORT -ga_opt_out $SSL 1> $OUTDIR/out.1 2>&1 & PID_1=$!
$JVM water.H2O -name $CLUSTER_NAME -baseport $CLUSTER_BASEPORT -ga_opt_out $SSL 1> $OUTDIR/out.2 2>&1 & PID_2=$!
$JVM water.H2O -name $CLUSTER_NAME -baseport $CLUSTER_BASEPORT -ga_opt_out $SSL 1> $OUTDIR/out.3 2>&1 & PID_3=$!

INTERFACE="lo0"

echo Running nonSSL test...

tshark -i ${INTERFACE} -T fields -e data -w ${OUTDIR}/h2o-nonSSL.pcap 1> /dev/null 2>&1 & PID_4=$!

java -ea -cp "build/libs/h2o-algos-test.jar${SEP}build/libs/h2o-algos.jar${SEP}../h2o-core/build/libs/h2o-core.jar${SEP}../h2o-core/build/libs/h2o-core-test.jar${SEP}../h2o-genmodel/build/libs/h2o-genmodel.jar${SEP}../lib/*" water.network.SSLEncryptionTest

cleanup

SSL="-ssl_config "$SSL_CONFIG

$JVM water.H2O -name $CLUSTER_NAME -baseport $CLUSTER_BASEPORT -ga_opt_out $SSL 1> $OUTDIR/out.1 2>&1 & PID_1=$!
$JVM water.H2O -name $CLUSTER_NAME -baseport $CLUSTER_BASEPORT -ga_opt_out $SSL 1> $OUTDIR/out.2 2>&1 & PID_2=$!
$JVM water.H2O -name $CLUSTER_NAME -baseport $CLUSTER_BASEPORT -ga_opt_out $SSL 1> $OUTDIR/out.3 2>&1 & PID_3=$!

echo Running SSL test...

tshark -i ${INTERFACE} -T fields -e data -w ${OUTDIR}/h2o-SSL.pcap 1> /dev/null 2>&1 & PID_4=$!

java -ea -cp "build/libs/h2o-algos-test.jar${SEP}build/libs/h2o-algos.jar${SEP}../h2o-core/build/libs/h2o-core.jar${SEP}../h2o-core/build/libs/h2o-core-test.jar${SEP}../h2o-genmodel/build/libs/h2o-genmodel.jar${SEP}../lib/*" water.network.SSLEncryptionTest

cleanup

testOutput