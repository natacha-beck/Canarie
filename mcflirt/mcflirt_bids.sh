
#!/bin/bash

#
# This program accepts a BIDS dataset and runs mcflirt on the subjects that have bold and asl files.
# See the usage statement for more information.
#

VERSION=1.0

usage() {
  cat <<USAGE
This is $0 version $VERSION by Pierre Rioux eddited by Safa Sanami for mcflirt
Usage: $0 BIDSDATASET OUTPUTDIR [almost any other options of mcflirt here]
This program has two mandatory arguments:
  * BIDSDATASET is a directory containing a standard BIDS data structure
  * OUTPUTDIR is any output directory of your choice, and will be created
    as needed. Under it, one subdorectories will be created:
      mc_output/
      
    and under each, there will be a subdirectory for each BIDS subject,
    either as "sub-1234" or "sub-1234_ses-abcd" (depending on whether or
    not the subject contains sessions). 

The rest of the options are ANY parameters supported by mcflirt, -i, -o. Supplying these options will
result in unpredicatble results, as it will confuse the internal
pipeline.
USAGE
  exit 2
}

die() {
  echo "$*"
  echo ""
  echo "Use $0 -h for help."
  exit 2
}


MCFLIRT_EXE="mcflirt"

# Check basic required args
test "X$1" = "X-h" && usage
test $# -lt 2      && usage
bidsdataset="$1"
deriv_out="$2"
shift;shift

# Verify main BIDS input dataset
test -d "$bidsdataset"                          || die "First argument must be a BIDS directory."
test -e "$bidsdataset/dataset_description.json" || die "BIDS dataset missing JSON description."

# Prepare output
mkdir -p "$deriv_out" || die "Cannot create output dir"

echo "$0 $VERSION starting at" `date`

# Scan subjects
for subjdir in "$bidsdataset"/sub-* ; do
  test -d "$subjdir" || continue # ignore any non-dir that happens ot start with sub-
  subject=$(basename $subjdir)

  # Extract list of sessions, or just '.' if there are none
  sesslist=$(ls -1f $subjdir | grep '^ses-' | sort)
  test -z "$sesslist" && sesslist="none"

  # Loop through sessions; if there are no sessions, we have a fake
  # one called 'none'.
  for session in $sesslist ; do
    test "$session" != 'none' && ( test -d "$subjdir/$session" || continue ) # ignore any non dir that happens to start with ses-

    # One variable that contains BIDSDATASET/sub-1234 or BIDSDATASET/sub-123/ses-123
    subdata="$subjdir"
    test "$session" != 'none' && subdata="$subdata/$session"

    # One variable with "sub-123" or "sub-123_ses-123"
    sub_sess="$subject"
    test "$session" != 'none' && sub_sess="${subject}_${session}"

    # Main Banner
    echo "======================================================="
    echo " SUBJECT $subject SESSION $session"
    echo "======================================================="
    
    # Find the list of asl files
    # files we also need.
    fmrifiles=${subdata}/func/${sub_sess}*bold.nii*
    aslfiles=${subdata}/perf/${sub_sess}*asl.nii*

    for fmrifile in $fmrifiles ; do

      if ! test -f "$fmrifile" ; then
        echo " -> Warning :No fmri file found, skipping. Expected one match in $fmrifile"
        continue
      fi

      # "BIDS/sub-1/{ses}/perf/{sub}_{ses}_{task}_{run}"
      perf_prefix=$(echo $fmrifile     | sed -e 's#_bold.nii.*##')
      

      # Variable to show sub, ses, task, run etc etc
      full_context=$(basename $perf_prefix)


      echo "-------------------------------------------------------"
      echo " MCFLIRT, Context=$full_context"
      echo "-------------------------------------------------------"
      mkdir -p "$deriv_out/mc_out" || die "Cannot create output dir for mcflirt ?!?"
      oasl_out="$deriv_out/mc_out/$full_context"
      oasl_log="$deriv_out/mc_out/$full_context.log"

      if test -d "$oasl_out" ; then
        echo " -> re-using mcflirt output in $oasl_out"
        echo " -> (if this output is corrupt, consider deleting it)"
        oasl_status=0
      else
        $MCFLIRT_EXE              \
          -i "$fmrifile"              \
          -o "$oasl_out"             \
          "$@"                       \
          2>&1 | tee "$oasl_log"
        oasl_status=$?
      fi

      if test $oasl_status -ne 0 ; then
        echo " -> ERROR: mcflirt failed, see logs in $oasl_log"
        continue
      fi

    done # BOLD image file loop

  done # sessions loop

done # subjects loop

echo "$0 ending at" `date`

