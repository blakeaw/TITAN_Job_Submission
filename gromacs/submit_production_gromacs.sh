#!/bin/bash

### USER - variables to set

#give the system to run -- used in the job name and can be called in SPATH
SYS="SysName"

#multiple copies are used for error bars and more robust results
COPY_START=4; #the first copy to start with
COPY_END=4; #the last copy to do
COPY_SKIP=( none ); # list any copy numbers between COPY_START and COPY_END that you want to skip

NP_START=0; #the first of the chained production runs for a copy-- 
# NOTE: number 0 is assumed to be the first production started from LASTEQUIL
# and then subsequent production runs for a copy are extended off each other using the extend flag  
NP_END=10; #the last of the chained production runs for a copy

EXTEND=1000; #block size in picoseconds-number of picoseconds to extend the subsquent production runs for a copy
 
ACCOUNT="account_name"; # account to charge the job to 
NODES=64; # number of nodes to request
WALLTIME="0:45:00"; #walltime to request for each run -- max is 2 hours

EMAIL_ME="TRUE"; # set to TRUE if you want to receive an email notification when jobs end
EMAIL_ADDRESS="myname@ornl.gov"; # if EMAIL_ME==TRUE; then;  set the email address where you want to receive job end notifications 

SPATH=${PROJWORK}/${ACCOUNT}/${SYS}/gromacs/; # the path to system your simulating (inlcuding trailing /)
#NOTE: the individual copy directories will be created inside the SPATH directory
# during the first step. example: for copy number 0, location will be SPATH/copy0 

USINGMODULE="FALSE"; # set to TRUE if you are using an existing TITAN module - FALSE otherwise
MODULENAME="none"; # if using TITAN module, give the name/version
USINGSOURCE="TRUE"; # set to TRUE if you want to call a source file - this will add a source call to the pbs 
#                   e.g. source GMXRC
SOURCEPATH="some_path_to/GMXRC"; #give the source path
EXEC="gmx_mpi"; # name of the executable -- if you are not using a TITAN module or source call, then give the full path 
#				to the program executable--include the binary name


PRODMDP="step7_production.mdp"; # give the name of the mdp file for the first block of the production run - in SPATH
LASTEQUIL="step6.6_equilibration.gro"; # give the name of the .gro file to start the first production run (number 0) from - in SPATH/COPY#nc#/

PROD_NAME_PRE="step7_prod"; # the name prefix for the production run outputs -- 
# Subsequent chained production runs (after number 0) will use this in place of LASTEQUIL
#                                      with (production run number - 1) 

GPUPERNODE=1 ; # number of GPUs on each node - TITAN = 1 
CORESPERNODE=16 ; # number of cores per node - TITAN = 16 - you can change this value if you want to use fewer cores than the max
#                 on a node.

#END variables to set

OMPTPN=$CORESPERNODE; # number of OpenMP threads to assign to each MPI rank
CORES=$(($NODES * $CORESPERNODE))
NMPIRANK=$NODES; # the number of MPI ranks - for gpu should be one per node
NGPU=$(($NODES * $GPUPERNODE))
# namd specific - for process mapping
CPNM1=$(( $CORESPERNODE - 1 ))
CPNM2=$(( $CORESPERNODE - 2 ))

#function to check if a value is in a list
# usage: list_contains list value
#returns true if the list contains the value
list_contains() {
	local ret="0"
	#echo "1"
	# use expansion to get the input array
	local name="$1[@]"
    a=("${!name}")
#	echo "a $a"
#	echo "2 $2"
	for value in "${a[@]}"; do
		if [ ${value} == ${2} ]; then
			#echo "----- $value 2 $2"
			ret="1"
		fi	
		
	done
	echo "${ret}"
	#exit
}
clear
## put in a double checker for the input values
echo "Please double check the inputs."
echo "Doing ${SYS} with "
echo " COPY_START ${COPY_START} COPY_END ${COPY_END}"
echo "COPY_SKIP ${COPY_SKIP}"
echo " NP_START ${NP_START} NP_END ${NP_END}"
echo " NODES $NODES"
echo " WALLTIME $WALLTIME"
echo " EMAIL_ME ${EMAIL_ME} EMAIL_ADDRESS ${EMAIL_ADDRESS}"
echo " SPATH: $SPATH"
echo " USINGMODULE $USINGMODULE MODULENAME $MODULENAME"
echo " USINGSOURCE $USINGSOURCE"
echo " SOURCEPATH $SOURCEPATH"
echo " EXEC: $EXEC"
echo " PRODMDP: ${PRODMDP}"
echo " LASTEQUIL: $LASTEQUIL"
echo " PROD_NAME_PRE: ${PROD_NAME_PRE}"

echo -n "Do you want to continue with these settings? [y/n]: "
read answer
case $answer in
	y )
		echo "OKAY! Will do."
		;;
	n ) 	
		echo "Alright, I won't do it. Fix what you need fix and try again."
		echo "QUITTING! Nothing was submitted."		
		exit
		;;
	* )
		echo "Well I don't understand your response, so I'm going to assume"
		echo " that you meant \"n\"."
		echo "QUITTING! Nothing was submitted."		
		exit
		;;
esac
#double check the SPATH to make sure it exists
if [ -d "$SPATH" ]; then
	cd $SPATH
else
	echo "ERROR!-- directory $SPATH does not exist!" 
	echo "check your path SPATH setting and try again."
	echo "QUITTING! Nothing was submitted."		
	exit
fi
#double check the exec path
if [[ $USINGMODULE != "TRUE" ]]; then
	if [[ $USINGSOURCE != "TRUE" ]]; then
		if [ ! -f "$EXEC"  ]; then
			echo "ERROR!-- file $EXEC does not exist!" 
			echo "check your path EXEC setting and try again."
			echo "QUITTING! Nothing was submitted."		
			exit
		fi
	fi
fi
#double check that the production template file exists 
if [ ! -f "${PRODMDP}" ]; then
	echo "ERROR!-- the production run input file ${PRODMDP} does not exist in ${SPATH}!" 
	echo "check your path PRODMPD setting and try again."	
	exit
fi
if [[ $USINGMODULE == "TRUE" ]]; then
	if [[ $USINGSOURCE == "TRUE" ]]; then
		
		echo "ERROR!-- you are using both a module and a source call!" 
		echo "check your USINGMODULE and USINGSOURCE settings and try again."
		echo "QUITTING! Nothing was submitted."		
		exit
		
	fi
fi
if [[ $USINGSOURCE == "TRUE" ]]; then
	if [ ! -f "$SOURCEPATH"  ]; then
		echo "ERROR!-- file $SOURCEPATH does not exist!" 
		echo "check your path SOURCEPATH setting and try again."
		echo "QUITTING! Nothing was submitted."		
		exit
	fi
fi

echo " "
#loop over the copies for this system
for (( i = COPY_START; i <= COPY_END; i++ )); do
	#
	#list_contains "COPY_SKIP" $i
	# pass the COPY_SKIP array by name
	SFLAG=`list_contains "COPY_SKIP" $i`
	#echo "SFLAG $SFLAG"
	if [[  $SFLAG == 1  ]]; then
		echo "Skipping copy number $i from COPY_SKIP list"
		continue
	fi
	echo "doing copy $i"
	COPY="copy${i}"
	# double check to make sure the COPY (i.e. copy${i}) dir exists
	if [ -d "$COPY" ]; then
		cd $COPY
		cp ../${PRODMDP} ./
	else
		echo "ERROR!-- directory $COPY does not exist!" 
		echo "check your path SPATH:"
		echo "$SPATH"
		echo -n "Do you want to continue with other copies? [y/n]: "
		read answer
		case $answer in
			y )
				echo "OKAY! Will do."
				echo "Skipping copy number $i"
				continue
				;;
			n ) 	echo "Alright, I won't do it. Fix what you need fix and try again."
				echo "QUITTING!"		
				exit
				;;
			* )
				echo "Well I don't understand your response, so I'm going to assume"
				echo " that you meant \"n\"."
				echo "QUITTING!"		
				exit
				;; 	
		esac
	fi
	#variable to store job id for chaining the successive runs
	JID=""
	#flag to denote the first of the productions - starts as 1 
	FIRSTP=1
	# for this copy, loop over the production runs
	for (( j = NP_START; j <= NP_END; j++ )); do
		echo "    doing production number ${j}"
		#generate the pbs script for the job
		ofile="${SYS}_c${i}_p${j}.pbs"
		echo "#!/bin/bash" > $ofile
		#    Begin PBS directives
		# Required 	The job will be charged to the ACCOUNT project.
		echo "#PBS -A ${ACCOUNT}" >> $ofile
		# Optional 	The job will be named "mem0_production"
		echo "#PBS -N ${SYS}_c${i}_p${j}" >> $ofile
		# Required 	The job will request compute nodes for walltime hours
		echo "#PBS -l walltime=${WALLTIME},nodes=${NODES}" >> $ofile
		##emails for begin (b), abort(a), and end (e)
		if [[ $EMAIL_ME == "TRUE" ]]; then
			echo "#PBS -M ${EMAIL_ADDRESS}" >> $ofile
			echo "#PBS -m e" >> $ofile
		fi
		
		#    End PBS directives and begin shell commands
		# This shell command will change to the user's $MEMBERWORK/$GROUP directory.
		echo "cd ${SPATH}${COPY}" >> $ofile
		
		## to get gromacs
		if [[ ${USINGMODULE} == "TRUE" ]]; then
			
			#import the module utility 
			echo "source \${MODULESHOME}/init/bash" >> $ofile
			#load the namd module
			echo "module load ${MODULENAME}" >> $ofile
		fi
			## to get gromacs
		if [[ ${USINGSOURCE} == "TRUE" ]]; then
			
			#load the gmxrc file
			echo "source ${SOURCEPATH}" >> $ofile
		fi

		CURRENT_RUN=`echo ${PROD_NAME//#np#/${j}}`
		echo "# this run is: ${CURRENT_RUN} of copy ${i} in system ${SYS}" >> $ofile


		#production run 0
		if [[ $j == 0 ]]; then
				#double check that the production mdp file exists 
			if [ ! -f "${PRODMDP}" ]; then
				echo "ERROR!-- the production mdp file ${PRODMDP} does not exist!" 
				echo "check your path PRODMDP setting and try again."
				echo "Skipping copy ${COPY}! Nothing was submitted for ${COPY}."	
				rm ${ofile}	
				#break the prod loop
				break
			fi
			if [ ! -f "${LASTEQUIL}"  ]; then
				#it doesn't exist
				echo "ERROR!-- the equilibrated .gro file ${LASTEQUIL} does not exist!" 
				echo "check your path LASTEQUIL setting and try again."
				echo "Skipping copy ${COPY}! Nothing was submitted for ${COPY}."	
				rm ${ofile}	
				#break the prod loop
				break
			fi
			
			#everthing checked out- continue preparing the pbs script
			#name and generate the current namd configuration file
			OF_PRE="${PROD_NAME_PRE}_c${i}_p${j}"
			echo "aprun gmx_mpi grompp -f ${PRODMDP} -o ${OF_PRE}.tpr -c ${LASTEQUIL} -p topol.top -gpu_id 0" >> $ofile
			echo "aprun -n ${NMPIRANK} -d ${OMPTPN} gmx_mpi mdrun -ntomp ${OMPTPN} -v -deffnm ${OF_PRE} " >> $ofile
			#submit production 0
			JID=`qsub ${ofile}`; #capture the job id for conditional execution of chained jobs	
		#other productions: successive production runs are chained off of each other using the -extend flag for gmx-convert		
			FIRSTP=0
			echo "     first of the productions.."
			echo "      job id: $JID"
			
		else
			PREV_PROD=$(( $j - 1 ))
			PREV_OF_PRE="${PROD_NAME_PRE}_c${i}_p${PREV_PROD}"
			OF_PRE="${PROD_NAME_PRE}_c${i}_p${j}"
			echo "aprun gmx_mpi convert-tpr -s ${PREV_OF_PRE}.tpr -f ${PREV_OF_PRE}.trr -e ${PREV_OF_PRE}.edr -o ${OF_PRE}.tpr -extend ${EXTEND}" >> $ofile
			echo "aprun -n ${NMPIRANK} -d ${OMPTPN} gmx_mpi mdrun -ntomp ${OMPTPN} -v -deffnm ${OF_PRE} -gpu_id 0" >> $ofile
			if [[ ${FIRSTP} == 1 ]]; then
				echo "     first of the productions.."
				JID=`qsub ${ofile}`; #capture the job id for conditional execution of chained jobs
				echo "      job id: $JID"
				FIRSTP=0				
			else
				PJID=${JID}
				JID=`qsub -W depend=afterok:${PJID} ${ofile}`	
				echo "      job id: $JID -- chained to job id ${PJID}"
			fi
			
		fi
	
	done; # end production run loop
	cd ${SPATH}
done; # end copy loop

echo "I'm all done with your request."
echo "Have a nice day!"
echo "### END OF LINE ###"
