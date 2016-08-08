# TITAN_Job_Submission
TITAN is a petascale supercomputer hosted by the Oak Ridge Leadership Computing Facility at Oak Ridge National Lab.

The shell scripts in the namd and gromacs directories are used to submit molecular dynamics simulations using NAMD and Gromacs respectively.
These scripts generate the .pbs files and submit them to qsub. 

 The scripts in PBSgen can be used to generate simpler .pbs files, which can then be manually submitted through qsub.
