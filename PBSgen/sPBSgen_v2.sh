#!/bin/bash
## Script to generate a pbs file for batch submission on a closer
## run witout arguments to see usage
### variables
# REQUIRED PBS vars
GROUP="FALSE" ; # input flag is -group="groupname"
WALLTIME="FALSE"; # input flag is -walltime="walltime"
NODES="FALSE"; # input flag is nodes=number_nodes

#Optional PBS vars - common
JOBNAME="TITAN_job"; # input flag is -jobname="job_name"

#Additional PBS commands
ADDPBS="FALSE"; # input flag is -addpbs="pbsdir1, pbsdir2"
ADDPBSDIR=""
# REQUIRED - give the thing to execute- include aprun and aprun_flags
EXECUTE="FALSE"; # input flag is -execute="aprun ap_flags binary bin_flags"

# the name of output PBS file
PBSNAME="run.pbs"; # input flag is -pbsname="pbs_name.pbs"

# the number of copies of the simulation to run - default is 1
NCOPIES=1; # input flag is -ncopies=int_number

# Users are limited to 50 aprun processes per batch job.
MAXCOPIES=50
MINCOPIES=1
#the storage area to run from and store output. Default is $MEMBERWORK
SDIR=$MEMBERWORK ; # to change to the $PROJWORK, use input flag -pdir
SPLACE="MEMBERWORK"
#Flag for multirep runs to be run in serial (ie not backgrounded) - defaut is FALSE
SERFLAG="FALSE"; # to change to serial, use input flag -serial
#Flag for multirep runs to executed in the same directory - default is FALSE
SDFLAG="TRUE"; # to change to same dir, use input flag -separatedir to generate separate directories for each copy
#Flag for variable expansion in the executable string" - defaut is FALSE
#EVFLAG="TRUE"; # activate with the -eval input flag
EXECFILE="FALSE"; # other option to set the executable. parses the file you give. use flag -execute-file="filename"
EXECFNAME="FALSE"
CDPWD="FALSE"; # flag for
CDDIRFLAG="FALSE"
####USAGE
MINARGS=4
NARGS=$#

if [[  $NARGS < $MINARGS ]]; then
    echo "Error: Not enough arguments!"
    echo "Usage - minimum: "
	echo "sPBSgen.sh -group=\"groupname\" -walltime=\"walltime\" -nodes=number_nodes -execute=\"aprun ap_flags binary bin_flags\""
	echo "Additional (optional) flags are:"
	echo "-jobname=\"job_name\": set the name of the job, -pbsname=\"pbs_name.pbs\": set the name of the pbs file that is generated. The defaut is \"run.pbs\""
	echo "-ncopies=int_number : set the number of duplicate simulations to run"
	echo "-addpbs=\"pbsdir1;pbsdir2\" : add any additional pbs directives using a semi-colon separated list (do not include #PBS)"
	echo "-pdir : switch to PROJWORK/GROUP storage directory. MEMBERWORK/GROUP is the default."
	echo "-bg : adds backgrounding for multi-rep jobs. i.e. the reps are all executed in the background, rather than in serial"
	echo "-separterdir : for multi-rep jobs. Places the rep executions in separate directories. "
	echo "-cdpwd : changes the default location for the batch execution to the current working directory. MEMBERWORK/GROUP is the default."
	echo "-cddir=\"some_path\" : changes the default location for the batch execution to the specified path. MEMBERWORK/GROUP is the default."
	echo "-execute-file=\"filename\" : This can be used in place of the -execute flag for single copy jobs. Use the commands in \"filename\" as the execute arguments."
	echo "OTHER FEATURES:"
	echo "The identifier '#r%' can be used inside the execute flag for multi-rep jobs to denote the rep number. The identifier will be replaced with the rep number."
	echo "        Example: -ncopies=2 -execute=\"aprun gmx mdrun in_#r%_rep.tpr\""
	echo "The identifier '#rp%' can be used inside the execute flag for multi-rep jobs to denote the rep number minus one. The identifier will be replaced with (rep number -1) on all reps greater than 1. On the first rep (1) it will simply be removed."
	echo "NOTES: "
	echo " For this script to work, you need to give the full paths to the simulation input files."
	echo " If you need to execute multiple commands/programs, you can put them all in the string for the execute flag using semi-colons"
	echo "e.g.: -execute=\"bash command;aprun prog1 in1;aprun prog2 in2\""
    exit
fi

#store the input flags for later
INFLAGS=`echo "$@"`
#parse the input flags
for i in "$@"
do
#echo $i
case $i in
	-group=*)
		GROUP="${i#*=}"
		#echo $GROUP
		shift
		;;
	-walltime=*)
		WALLTIME="${i#*=}"
		shift
		;;
	-nodes=*)
		NODES="${i#*=}"
		# check nodes argument, should be a positive integer
		case ${NODES#[+]} in *[!0-9]* )
			echo "Error: NODES -> \"$NODES\" is not a positive integer. The number of nodes should be a positive integer!";
			exit ;;
		esac
		shift
		;;
	-jobname=*)
		JOBNAME="${i#*=}"
		shift
		;;
	## not quite sure how to do this one yet...
	-addpbs=*)
		TEMP="${i#*=}"
		ADDPBS="TRUE"
		ADDPBSDIR=$(echo $TEMP | tr "," "\n")

		shift
		;;
	-pbsname=*)
		PBSNAME="${i#*=}"
		shift
		;;
	-execute=*)
		EXECUTE="${i#*=}"
		shift
		;;
	-ncopies=*)
		NCOPIES="${i#*=}"

		# check nodes argument, should be a positive integer
		case ${NCOPIES#[+]} in *[!0-9]* )
			echo "Warning: NCOPIES -> \"$NCOPIES\" is not a positive integer. The number of copies should be a positive integer greater than 0!"
			echo "setting NCOPIES back to the default $MINCOPIES"
			NCOPIES=1;;
			#exit ;;
		esac
		if [[ $NCOPIES >  $MAXCOPIES ]]; then
			echo "ncopies is greater than the allowed maximum! Setting to max $MAXCOPIES"
			NCOPIES=$MAXCOPIES
		fi
		if [[ $NCOPIES < $MINCOPIES ]]; then
			echo "ncopies is less than the allowed mimimum! Setting back to default 1"
			NCOPIES=$MINCOPIES
		fi
		shift
		;;
	-pdir)
		SDIR=$PROJWORK
		SPLACE="PROJWORK"
		shift
		;;
	-bg)
		SERFLAG="FALSE"
		shift
		;;
	-separatedir)
		SDFLAG="FALSE"
		shift
		;;
## additional functionality to be added
#	-chain-multi)
#		shift
#		;;
	-execute-file=*)
		#EXECUTE="TRUE"
		EXECFILE="TRUE"
		EXECFNAME="${i#*=}"
		shift
		;;
	-cdpwd)
		CDPWD="TRUE"
		shift
		;;
	-cddir=*)
		#EXECUTE="TRUE"
		CDDIRFLAG="TRUE"
		CDDIR="${i#*=}"
		shift
		;;

#	-eval-vexp)
#		EVVFLAG="TRUE"
#		shift
#		;;
#	-eval-cexp)
#		EVCFLAG="TRUE"
#		shift
#		;;
esac
done
echo "Preparing PBS (batch submission script)"

#check required PBS vars
if [[ $GROUP == "FALSE" ]]; then
	echo "Need to set the group!! group=$GROUP"
	echo "Use the -group=\"group_name\" flag"
	exit
fi
echo "GROUP $GROUP"

if [[ $WALLTIME == "FALSE" ]]; then
	echo "Need to set the walltime!! walltime=$WALLTIME"
	echo "Use the -walltime=\"wall_time\" flag"
	exit
fi
echo "WALLTIME $WALLTIME"

if [[ $NODES == "FALSE" ]]; then
	echo "Need to set the nodes!! nodes=$NODES"
	echo "Use the -nodes=n_nodes flag"
	exit
fi
echo "NODES $NODES"
if [[ $EXECUTE == "FALSE" ]]; then
	#check execute file
	if [[ $EXECFILE == "FALSE" ]]; then
		echo "Need to set the executable!! execute=$EXECUTE execfile=$EXECFILE"
		echo "Use the -execute=\"executables\" flag"
		echo "OR- the -execute-file=\"filename\" flag"
		exit
	fi

fi
echo "EXECUTE $EXECUTE"

## begin building the PBS file
echo "#!/bin/bash" > $PBSNAME
echo "## PBS batch submission script generated by sPBSgen.sh" >> $PBSNAME
echo "## Input flags were: $INFLAGS" >> $PBSNAME
echo "#    Begin PBS directives" >> $PBSNAME
echo "# Required 	The job will be charged to the \"$GROUP\" project." >> $PBSNAME
echo "#PBS -A $GROUP" >> $PBSNAME
echo "# Optional 	The job will be named \"$JOBNAME\"" >> $PBSNAME
echo "#PBS -N $JOBNAME" >> $PBSNAME
echo "# Required 	The job will request $NODES compute nodes for $WALLTIME hours" >> $PBSNAME
echo "#PBS -l walltime=$WALLTIME,nodes=$NODES" >> $PBSNAME
##additional PBS directives
if [[ $ADDPBS == "TRUE" ]]; then
	OIFS=$IFS
	echo "## additional PBS directives" >> $PBSNAME
	# split the directives into a bash array
	IFS=';' read -r -a darray <<< "$ADDPBSDIR"
	# loop over the directives array (darray)
	for dir in "${darray[@]}"
	do
		echo "#PBS $dir" >> $PBSNAME
	done
	IFS=$OIFS
fi
echo "#    End PBS directives and begin shell commands" >> $PBSNAME

echo " "
echo "# This shell command will run the date command." >> $PBSNAME
echo "date" >> $PBSNAME
THE_USER=`whoami`
CWORK="${THE_USER}_${GROUP}_${JOBNAME}"
#if [ -d "$CWORK" ]; then
  # Control will enter here if $DIRECTORY exists.
#  echo "# The subdirectory $CWORK already exists" >> $PBSNAME
#fi
#if [ ! -d "$CWORK" ]; then
  # Control will enter here if $DIRECTORY doesn't exist.
if [[ $CDPWD == "TRUE" ]]; then

	echo "# cd into the \$PWD directory" >> $PBSNAME
	echo "cd $PWD" >> $PBSNAME
elif [[ $CDDIRFLAG == "TRUE" ]]; then
	echo "# cd into the \$CDDIR directory" >> $PBSNAME
	echo "cd $CDDIR" >> $PBSNAME
else
	echo "# This shell command will change to the user's \$${SPLACE}/\$GROUP directory." >> $PBSNAME
	echo "# user ${USER}'s \$${SPLACE}/\$GROUP directory is: $SDIR/$GROUP"
	echo "cd \$${SPLACE}/$GROUP" >> $PBSNAME
	echo "# This shell command will create a subdirectory for the new job" >> $PBSNAME
	echo "mkdir $CWORK" >> $PBSNAME
	echo "# cd into the new subdirectory" >> $PBSNAME
	echo "cd $CWORK" >> $PBSNAME
fi
#store a temporary copy of the pbs "headers"
cat $PBSNAME > pbsgen_head.temp
if [[ $EXECFILE == "TRUE" ]]; then
	if [[ $NCOPIES > 1 ]]; then
		echo "Warning: NCOPIES set with -ncopies flag cannot be greater than 1 when using -execute-file flag"
		echo "----Changing NCOPIES from $NCOPIES to 1"
		NCOPIES=1
	fi
fi
if [[ $NCOPIES == 1 ]]; then

	if [[ $EXECFILE == "TRUE" ]]; then
		# parse the execute file
		#read line by line
		echo "# This invocation will run 1 copy of the commands in \"$EXECFNAME\" on the compute nodes allocated by the batch system." >> $PBSNAME
		#EFF_MULTI="%multi"
		#EFF_CHAIN="%chain"
		echo "Reading exec-file : $EXECFNAME"
		# parse the file line by line -- this opens the possibility of inline command options--not using for now
#		while read -r line
#		do
#			echo "${line}" >> $PBSNAME
#		done < ${EXECFNAME}
		#cat the file and put into the output
		cat ${EXECFNAME} >> $PBSNAME
	else

		echo "# This invocation will run 1 copy of the executable \"$EXECUTE\" on the compute nodes allocated by the batch system." >> $PBSNAME
	#	if [[ $EVFLAG == "TRUE" ]]; then
	#		EXECUTE=`eval "echo ${EXECUTE}"`
	#	fi
		echo "$EXECUTE" >> $PBSNAME
	fi
fi
if [[ $NCOPIES > 1 ]]; then
####### Decided not to allow use of execfile with ncopies>1 because I think that functionality
####### can be achieved in the exec file by the user
#	if [[ $EXECFILE == "TRUE" ]]; then
#		echo "# This invocation will run $NCOPIES copies of the commands in \"$EXECFNAME\" on the compute nodes allocated by the batch system." >> $PBSNAME
#		#EFF_MULTI="%multi"
#		#EFF_CHAIN="%chain"
#		echo "Reading exec-file : $EXECFNAME"
#		while read -r line
#		do
#
#			echo "${line}" >> $PBSNAME
#		done < ${EXECFNAME}
#	else

		echo "# This invocation will run $NCOPIES copies of the executable \"$EXECUTE\" on the compute nodes allocated by the batch system." >> $PBSNAME
		# check for the serial flag
		if [[ $SERFLAG == "FALSE" ]]; then
			EXECUTE=`echo "$EXECUTE &"`
		fi
		if [[ $SDFLAG == "TRUE" ]]; then
			echo "# Running mulitple copies with -samedir flag, so do not make subdirectories for each copy" >> $PBSNAME
			for (( i = 1; i <= NCOPIES; i++ )); do
				echo "# copy number ${i}" >> $PBSNAME
				NEXECUTE=`echo ${EXECUTE//#r%/${i}}`
				im1=`expr $i - 1`
				#echo "im1 $im1"
				NEXECUTE=`echo ${NEXECUTE//#rp%/${im1}}`
				echo "$NEXECUTE" >> $PBSNAME

			done
		else
			echo "# Running mulitple copies, so make subdirectories for each copy" >> $PBSNAME
			for (( i = 1; i <= NCOPIES; i++ )); do
				echo "# copy number ${i}" >> $PBSNAME
				echo "mkdir copy_${i}" >> $PBSNAME
				echo "cd copy_${i}" >> $PBSNAME
				NEXECUTE=`echo ${EXECUTE//#r%/${i}}`
				im1=`expr $i - 1`
				#echo "im1 $im1"
				NEXECUTE=`echo ${NEXECUTE//#rp%/${im1}}`
				echo "$NEXECUTE" >> $PBSNAME
				echo "cd .." >> $PBSNAME
			done
		fi
		if [[ $SERFLAG == "FALSE" ]]; then
			echo -e "# The wait command will prevent the batch script \n # from returning until each background-ed aprun completes.\n # Without the \"wait\" the script will return once each aprun has been started, \n # causing the batch job to end, which kills each of the background-ed aprun processes." >> $PBSNAME
		echo "wait" >> $PBSNAME
		fi
fi


## done with writing the PBS

echo "PBS writing complete!"
echo "The name is: $PBSNAME"
#echo "preview of the file:"
#cat $PBSNAME
echo "to sumbit:"
echo " qsub $PBSNAME"
echo "Before submitting, make sure you loaded the necessary modules."
echo "Best of luck and good day to you!"
