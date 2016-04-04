#1/bin/bash

# enables debug mode
set -x
set -e
set -o nounset
set -o pipeline

EXPAND=true
QUOTEFILTER=true
KEEPBEST=true

CONFIG=$1


: ${KBPOPENREPO:?"Need to set KBPOPENREPO to path to working copy of kbp-2014-event-arguments"}
#: ${PARTICIPANTS:?"Need to set PARTICIPANTS to /nfs/mercury-04/u22/kbp-2015/eval_analysis/interim_2015/systemsOutput"}
#: ${ASSESSMENTS:?"Need to set $ASSESSMENTS to /nfs/mercury-04/u22/kbp-2015/eval_analysis/interim_2015/assessments"}

EVALDIR=${KBPOPENREPO}/output/${CONFIG}
LOG=$EVALDIR/log
PARTICIPANTS=${EVALDIR}/systemsOutput
ASSESSMENTS=${EVALDIR}/assessments

PARAMSDIR=${KBPOPENREPO}/params/${CONFIG}

mkdir -p ${PARAMSDIR}/generated/${CONFIG}


echo "Using working copy $KBPOPENREPO"
echo "Running config $CONFIG"
echo "Writing log to $EVALDIR/log"

# clear previous run, if any
echo "Output will be written to $EVALDIR"
echo "Clearing previous output, if any"
rm -rf $EVALDIR/expanded
rm -rf $EVALDIR/graphAnalyses
rm -rf $EVALDIR/keepBest
rm -rf $EVALDIR/log
rm -rf $EVALDIR/quoteFiltered
rm -rf $EVALDIR/score


echo "Creating output directory"
mkdir -p $EVALDIR/log

# uncompress participant submissions
#PARTICIPANTCOPY=$EVALDIR/participantSubmissions
#mkdir -p $PARTICIPANTCOPY
#echo "Copying participant submissions from $PARTICIPANTS to $PARTICIPANTCOPY"
#cp -r $PARTICIPANTS/* $PARTICIPANTCOPY


# copy LDC assessments
#LDCCOPY=$EVALDIR/ldcAssessment
#ASSESSDIR=$LDCCOPY/data/LDC_assessments
#echo "Copying LDC assessments from $ASSESSMENTS to $ASSESSDIR"
#mkdir -p $ASSESSDIR
#cp -r $ASSESSMENTS/{annotation,linkingStore} $ASSESSDIR/

# apply realis expansion to LDC assessments
if [ "$EXPAND" = true ]; then
    echo "Expanded assessment store using realis assessments..."
    $KBPOPENREPO/tac-kbp-eal/target/appassembler/bin/expandByRealis $PARAMSDIR/expand.params > $LOG/expand.log

    mkdir -p $EVALDIR/expanded/linkingStore
    cp $ASSESSMENTS/linkingStore/* $EVALDIR/expanded/linkingStore
fi

# quote filter participant submissions
if [ "$QUOTEFILTER" = true ]; then
    echo "Applying quote filter to submissions..."
    $KBPOPENREPO/tac-kbp-eal/target/appassembler/bin/applyQuoteFilter $PARAMSDIR/quoteFilter.params > $LOG/quoteFilter.log
fi

# do keepBest
if [ "$KEEPBEST" = true ] ; then
    echo "Applying keep best to systems"

    for f in $EVALDIR/quoteFiltered/*; do
      if [ -d ${f} ]; then
        sysId=$(basename $f)
        mkdir -p $EVALDIR/keepBest/$sysId

	cat <<EOF > $PARAMSDIR/generated/$CONFIG/keepBest_${sysId}.params
inputStore: $f
outputStore: $EVALDIR/keepBest/$sysId
keepInferenceCases: false
outputLayout: KBP_EA_2015
EOF

        $KBPOPENREPO/tac-kbp-eal/target/appassembler/bin/keepOnlyBestResponses $PARAMSDIR/generated/$CONFIG/keepBest_${sysId}.params > $LOG/keepBest_${sysId}.log
      fi
    done
fi


mkdir -p $EVALDIR/score/withRealis
$KBPOPENREPO/tac-kbp-eal-scorer/target/appassembler/bin/scoreKBPAgainstERE $PARAMSDIR/BBNKBPScorer2016.params > $LOG/scorer2016.log

