# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 
# ---- FreeSurfer Testing Framework ----
# 
# This is the underlying framework used for various regression tests throughout the freesurfer
# source tree. It should facilitate easy command testing and comparison of test output against
# reference data. A test for a script or binary should directly source this file via relative
# paths so that the test can be run in any directory (so to facilitate out-of-source builds).
# For example, a test script in the mri_convert subdirectory should include the following at
# the top of the file:
#
#     source "$(dirname $0)/../test.sh"
#
# This framework assumes that all test data is stored as a 'testdata.tar.gz' tarball in the
# directory where the test script lives. By default, this testdata tarball will be extracted
# every time a command is evaluated using the test_command function. Example:
#
#     test_command mri_convert rawavg.mgz orig.mgz --conform
# 
# will evaluate this usage of mri_convert and will error out upon failure. The test_command
# function will always evaluate a command within the testdata directory extracted from
# testdata.tar.gz, and it assumes that the binary to be tested (mri_convert in this example)
# has been built in either the directory from which the test script was run or the directory
# where the test script exists.
#
# Test output can be compared against reference data with the following functions:
#
#     compare_file  - wraps the standard unix diff command
#     compare_vol   - wraps mri_diff
#     compare_surf  - wraps mris_diff
#     compare_lta   - wraps lta_diff
#     compare_annot - wraps mris_annot_diff
#
# It is important that the argument order for all of these commands is as follows:
#
#     compare <real output> <expected output> [extra flags]
# 
# This is required so that the test reference data can be easily regenerated by supplying the
# --regenerate flag to the test script.
# 
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# make sure the script errors out after all failures
set -e
set -o pipefail

# get the os
get_os()
{
   local version=""
   local name=""
   local host_os=""
   local uname_linux=`uname -a | grep -i "^Linux"`
   local uname_darwin=`uname -a | grep -i "^Darwin"`

   if [ "$uname_linux" != "" ]; then
      # For version and name, all values after the = sign, then remove double quotes.
      # For name, use only 1st output field, remove point release info in version, change text to lowercase
      # Starting with MacOS 11.X, Apple changed the name from MacOSX to macOS, so last step is remove x from macosx
      version=`cat /etc/os-release | grep "^VERSION=" | sed 's;^.*=;;' | sed 's;";;g' | awk '{print $1}' | sed 's;\..*;;'`
      name=`cat /etc/os-release | grep "^ID=" | sed 's;^.*=;;' | sed 's;";;g' | tr '[:upper:]' '[:lower:]'`
   elif [ "$uname_darwin" != "" ]; then
      # For version, print 2nd field and remove any point release info in the os revision.
      # For name, print everything after colon, remove spaces, change text to lowercase
      version=`sw_vers | grep "^ProductVersion" | awk '{print $2}' | sed 's;\..*;;'`
      name=`sw_vers | grep "^ProductName" | sed 's/^.*://' | sed 's; ;;g' | tr '[:upper:]' '[:lower:]' | sed 's;osx;os;'` 
   fi

   # example output: centos7 centos8 ubuntu18 ubuntu20 macos10 macos11
   if [[ "$version" != "" ]] && [[ "$name" != "" ]]; then host_os=${name}${version}; fi
   echo $host_os
}

# error_exit
# simple error function
function error_exit {
    >&2 echo "$(tput setaf 1)error:$(tput sgr 0) $@"
    exit 1
}

# realpath <path>
# portable function to trace the absolute path
function realpath {
    echo $(cd $(dirname $1); pwd)/$(basename $1)
}

# first, parse the commandline input
for i in "$@"; do
    case $i in
        -r|--regenerate)
        # regenerate the test reference data
        FSTEST_REGENERATE=true
        shift
        ;;
        *)
        error_exit "unknown argument '$i'"
        ;;
    esac
done

# next, define some common paths

# FSTEST_CWD represents the directory from the where the test is initially run. In almost all cases,
# the binary to be tested should be built in this directory
FSTEST_CWD="$(pwd)"

# FSTEST_TESTDATA_DIR is the temporary testdata directory that gets untarred into FSTEST_CWD. All
# test commands are run from this directory
FSTEST_TESTDATA_DIR="${FSTEST_CWD}/testdata"

# FSTEST_SCRIPT_DIR is the location of the current test.sh script. In an in-source build, this directory
# will be the same as the FSTEST_CWD
FSTEST_SCRIPT_DIR="$(realpath $(dirname $0))"

# FSTEST_TESTDATA_TARBALL is the path to the testdata tarball associated with the current test script
FSTEST_TESTDATA_TARBALL="${FSTEST_SCRIPT_DIR}/testdata.tar.gz"
# For systems where we build with gcc 8.X, optionally use a testdata file whose reference output was
# created with binaries compiled with gcc8.X - whose output differs compared to binaries created with gcc 4.X
host_os=$(get_os)
export TESTDATA_SUFFIX=""
if [[ "$host_os" == "centos8" ]] || [[ "$host_os" == "ubuntu20" ]]; then
   # FSTEST_TESTDATA_TARBALL="${FSTEST_SCRIPT_DIR}/testdata_gcc8.tar.gz"
   export TESTDATA_SUFFIX=".gcc8"
elif [ "$host_os" == "macos10" ]; then
   export TESTDATA_SUFFIX=".clang12"
fi

# if we're regenerating testdata, make a temporary 'testdata_regeneration' storage directory for
# new reference data. After each comparison called in the test, the 'real' ouput will be copied into
# this regeneration directory as the new 'reference' output, and after the test finished, this directory
# will be tarred to replace the original FSTEST_TESTDATA_TARBALL
if [ "$FSTEST_REGENERATE" = true ]; then
    echo "regenerating testdata"
    # make the temporary dir and untar the original testdata into this directory
    FSTEST_REGENERATION_DIR="${FSTEST_CWD}/testdata_regeneration"
    rm -rf $FSTEST_REGENERATION_DIR && mkdir $FSTEST_REGENERATION_DIR
    tar -xzvf "$FSTEST_TESTDATA_TARBALL" -C $FSTEST_REGENERATION_DIR
fi

# find_path <start> <pattern>
# searches up a starting directory for a file (or filepath) that matches a particular pattern
function find_path {
    parent="$(dirname $1)"
    if [ -e "$parent/$2" ]; then
        echo "$parent/$2"
    elif [ "$parent" = "/" ]; then
        error_exit "recursion limit - could not locate '$2' in tree"
    else
        find_path $parent $2
    fi
}

# we want to use the installation target path as our FREESURFER_HOME, and the easiest way to extract that
# is by grabbing the CMAKE_INSTALL_PREFIX variable value from the CMakeCache.txt, which should exist
# somewhere in the current tree
CMAKECACHE=$(find_path $FSTEST_CWD CMakeCache.txt)
export FREESURFER_HOME="$(grep '^CMAKE_INSTALL_PREFIX:' $CMAKECACHE | cut -d = -f 2)"
export SUBJECTS_DIR="$FSTEST_TESTDATA_DIR"
export FSLOUTPUTTYPE="NIFTI_GZ"

# source the local freesurfer distribution
export PATH="$FREESURFER_HOME/bin:$PATH"

# set martinos license for internal developers
if [ -e "/autofs/space/freesurfer/.license" ] ; then
    export FS_LICENSE="/autofs/space/freesurfer/.license"
fi

# exit hook to cleanup any remaining testdata
function cleanup {
    FSTEST_STATUS=$?
    if [ "$FSTEST_STATUS" = 0 ]; then
        if [ "$FSTEST_REGENERATE" = true ]; then
            # tar the regenerated data
            cd $FSTEST_REGENERATION_DIR
            tar -czvf testdata.tar.gz testdata
            # make sure the annex file is unlocked before replacing it
            cd $FSTEST_SCRIPT_DIR
            git annex unlock testdata.tar.gz
            mv -f ${FSTEST_REGENERATION_DIR}/testdata.tar.gz .
            rm -rf $FSTEST_REGENERATION_DIR
            echo "testdata has been regenerated - make sure to run 'git annex add testdata.tar.gz' to rehash before committing"
            cd $FSTEST_CWD
        else
            echo "$(tput setaf 2)success:$(tput sgr 0) test passed"
        fi
        # remove testdata directory
        rm -rf $FSTEST_TESTDATA_DIR
    else
        echo "$(tput setaf 1)error:$(tput sgr 0) test failed"
    fi
}
trap cleanup EXIT

# hook to catch if the script is killed
function abort {
    error_exit "script has been killed"
}
trap abort SIGINT SIGTERM

# eval_cmd <command>
# prints a command before running it
function eval_cmd {
    echo ">> $(tput setaf 3)$@$(tput sgr 0)"
    eval $@
}

# refreshes (or initializes the testdata directory). By default, this gets run
# every time a new command is tested
function init_testdata {
    cd $FSTEST_CWD
    rm -rf $FSTEST_TESTDATA_DIR
    tar -xzvf "$FSTEST_TESTDATA_TARBALL"
    cd $FSTEST_TESTDATA_DIR
}

# test_command <command>
# "tests" a command with refreshed testdata. The command will always be run in the
# testdata directory.
# options:
#     FSTEST_NO_DATA_RESET: the testdata directory will not be reset
#     EXPECT_FAILURE: evaluation will fail if the command returns successfully
function test_command {
    # first extract the testdata
    if [ -z ${FSTEST_NO_DATA_RESET} ]; then
        init_testdata
    fi
    cd $FSTEST_TESTDATA_DIR
    # turn off errors if expecting a failure
    if [ -n "$EXPECT_FAILURE" ]; then
        set +e
    fi
    # run the command
    eval_cmd $@
    retcode=$?
    # reset settings and check error if failure was expected
    if [ -n "$EXPECT_FAILURE" ]; then
        if [ "$retcode" = 0 ]; then
            error_exit "command returned 0 exit status, but expected a failure"
        fi
        set -e
    fi
}

# run_comparison <diff command> <output> <reference> [extra options]
# wraps a diff command so that if testdata regeneration is turned on, no diff is run and
# the output file is copied into the regeneration directory as the reference file. It is very important
# that the 1st argument to the diff command is the real output and the 2nd argument is the expected output
function run_comparison {
    if [ "$FSTEST_REGENERATE" = true ]; then
        cp -f ${FSTEST_TESTDATA_DIR}/$2 ${FSTEST_REGENERATION_DIR}/testdata/$3
    else
        eval_cmd "$@"
    fi
}

# runs a standard diff on an output and reference file - all extra opts are passed to diff
function compare_file {
    run_comparison diff $@
}

# runs mri_diff on an output and reference volume - all extra opts are passed to mri_diff
function compare_vol {
    run_comparison mri_diff $@ --debug
}

# runs mris_diff on an output and reference surface - all extra opts are passed to mris_diff
function compare_surf {
    run_comparison mris_diff $@ --debug
}

# runs lta_diff on an output and reference transform - all extra opts are passed to lta_diff
function compare_lta {
    run_comparison lta_diff $@
}

# runs mris_annot_diff on an output and reference annotation - all extra opts are passed to mris_annot_diff
function compare_annot {
    run_comparison mris_annot_diff $@
}
