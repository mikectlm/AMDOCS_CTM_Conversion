#!/bin/perl

#USAGE
# perl XML_gen.pl -in "Bill_BillCycle_C99M22Y2015.req"

use XML::LibXML;

&Set_Variables_and_Config_file ();

open (BILLING_CONFIG_FILE,"${config_dir}/${config_file}") || die "Can't open $config_dir/$config_file";

while ($command_line=<BILLING_CONFIG_FILE>) {
  chomp ($command_line);
  ($command,$param1,$param2,$param3,$param4,$param5) = split (/\s+/,$command_line);

  SWITCH:  {
     if ($command =~ /^InsertRequest$/)      	{ &InsertRequest()       ;last SWITCH }
     if ($command =~ /^InsertOpprogSch$/) 	{ &InsertOpprogSch()	 ;last SWITCH }
     if ($command =~ /^InsertOpparSch$/) 	{ &InsertOpparSch()	 ;last SWITCH }
     if ($command =~ /^InsertOpprogSchFol$/) 	{ &InsertOpprogSchFol()	 ;last SWITCH }
     if ($command =~ /^InsertOpparSchFol$/)	{ &InsertOpparSchFol()	 ;last SWITCH }
     if ($command =~ /^FillTableField$/)	{ &FillTableField() 	 ;last SWITCH }
     if ($command =~ /^(FOR|NEXT)$/)	 	{ &UpdateLoopIndicatr()	 ;last SWITCH }
     &DoNothing;	### For any other commands - IGNORE
  }
}
close (BILLING_CONFIG_FILE);

print "Start preparing Control-M files\n";
&Create_SubTables_Files();
&Create_SubTable_Dependencies() ;
&Create_Jobs_Files() ;
&Create_Jobs_Dependencies() ;
&Create_XML_FileForDelivery() ;
print "Finished preparing Control-M files\n\n";

#Set variables for use by jobs and configs
sub Set_Variables_and_Config_file {

  @mapTypeTemp = split('_', $ARGV[1]);
  $mapType = $mapTypeTemp[1]  . "_cfg";
  $ReadRequestFile = $ARGV[1];

  #set map type from file name    
  
  open(REQ_FILE,"$ReadRequestFile") || die "can't open config request file";

  while ($read_line = <REQ_FILE>) {
	chomp($read_line);
	if ($read_line =~ /Year\s+(\d+)/) 	{ $Year = $1 }
	if ($read_line =~ /Cycle\s+(\d+)/) 	{ $Cycle = $1 }
	if ($read_line =~ /Month\s+(\d+)/) 	{ $Month = $1 }
	if ($read_line =~ /Rerun_Indicator\s+(\w+)/) 	{ $Rerun = $1 }
	if ($read_line =~ /Prep_Parallel\s+(\d+)/) 	{ $PrepParallel = $1 }
	if ($read_line =~ /Prod_Parallel\s+(\d+)/) 	{ $ProdParallel = $1 }
	if ($read_line =~ /Immediate_Start\s+(\w)/) 	{ $ImmediateStart = $1 }
  }

  close (REQ_FILE);

    print "Cycle " . $Cycle . "\n";
	print "Month " . $Month . "\n";
	print "Year " . $Year . "\n";
	print "Rerun " . $Rerun . "\n";
	print "mapType " . $mapType . "\n";
	print "PrepParallel " . $PrepParallel . "\n";  
	print "ProdParallel " . $ProdParallel . "\n";  
	print "ImmediateStart " . $ImmediateStart . "\n";  
  
  if (($Cycle =~ /^$/) || ($Month =~ /^$/)   || ($Year =~ /^$/) || ($Rerun =~ /^$/) || ($mapType =~ /^$/) || ($PrepParallel =~ /^$/) || ($ProdParallel =~ /^$/)) {
	print "The request file - $ReadRequestFile should contain the following - \n";
	print "Cycle          	15\n";
	print "Month          	5\n";
	print "Year           	2010\n";
	print "Prep_Parallel          	3\n";
	print "Prod_Parallel          	6\n";
	print "Rerun_Indicator:	 Y\n";
	print "Immediate_Start  Y\n\n\n";
 #Cycle 99
 #Month 22
 #Year 2015
 #Prep_Parallel	12
 #Prod_Parallel	13
 #Rerun_Indicator	N
 #Immediate_Start	Y
	exit (5);
  }
  #$config_dir = "$ENV{TLG_ETC}";
  $config_dir = "C:\\Users\\mbobbato\\Documents\\Work\\Rogers\\mike_scripts";
  $config_file= $mapType;
  
  $Proj   = 'V21';
  $Market = 'CAN';
  $MaxWaitDays = '60';

  $InsideLoopIndctr=0; 
  
  #SET BILL CONFIG TYPE CODES
  $Code{"BillConfirm_cfg"}='BCF';	$Code_Char{"BCF"} ='C';
  $Code{"BillConfirmNonBT_cfg"}='NBC';	$Code_Char{"NBC"} ='T';
  $Code{"BillCycleRerun_cfg"}='BCR';	$Code_Char{"BCR"} ='X';
  $Code{"BillCycle_cfg"}='BLC';		$Code_Char{"BLC"} ='B';
  $Code{"BillPreRerate_cfg"}='BPR';	$Code_Char{"BPR"} ='R';
  $Code{"BillPrep_cfg"}='BLP';		$Code_Char{"BLP"} ='P';
  $Code{"BillQA_cfg"}='BQA';		$Code_Char{"BQA"} ='Q';
  $Code{"BillUndoS_cfg"}='BUS';		$Code_Char{"BUS"} ='S';
  $Code{"BillUndo_cfg"}='BLU';		$Code_Char{"BLU"} ='U';
  $Code{"BillProd_cfg"}='BPD';		$Code_Char{"BPD"} ='D';

  $ConfigMapType = $Code{"$config_file"};
  $CodeChar = $Code_Char{"$ConfigMapType"};
  
  #SET APPL AND BILL TYPE CODES
  $Cycle =  sprintf("%02d", $Cycle);
  $Month =  sprintf("%02d", $Month);
  $Rerun_NO =  sprintf("%02d", $Rerun);
  $Yr    =  substr($Year,2,2);

 
  $ApplCycleCode  = "C${Cycle}M${Month}Y${Yr}_R${Rerun}";		### example: C15M03Y10R3
  $BillCycleNoYearCode = "C${Cycle}R${Rerun}";
  $BillCycleCode  = "${CodeChar}${Cycle}${Month}${Year}";   		### example: B15032010
  $TableCycleCode = "${Rerun}${CodeChar}${Cycle}${Month}";  		### example: 1B1503  
  $CpuCycleCode   = "${ConfigMapType}_${Cycle}${Month}_R${Rerun}";   	### example: BCF_1503_R1

  $SmartTable = "${Proj}_${ConfigMapType}_${BillCycleNoYearCode}";
  
  $ApplicationName = "${Proj}_${ConfigMapType}_${ApplCycleCode}";
  
  $Dir="C${Cycle}_M${Month}_Y${Year}_R${Rerun}_P${ProdParallel}_${ConfigMapType}";  ### example: C15_M03_Y2010_R1_P16_BCF

  $output_dir = "C:\\Users\\mbobbato\\Documents\\Work\\Rogers\\mike_scripts\\$Dir";

  if (-d $output_dir) {
	print "\n\n\ About to remove EXISTING $output_dir\n\n";
	system ("del /S /Q $output_dir > nul") ;
  }
  mkdir $output_dir,0755 || die "can't create $output_dir\n";
	
}

##NOT USED IN THIS SCRIPT - THIS IS FOR OPS DB INSERT
sub InsertRequest {

	### Example: InsertRequest BLCONFIRM BLDINIT GROUP   NULL    USG2
	###          $command      $param1   $param2 $param3 $param4 $param5
	###	     InUse         InUse     NIU     InUse   NIU     InUse
	###
	###         where NIU - Not In Use
	###
	###	As this command is populating the JOB_REC details in 
	###	OPPAR and OPPAR_DB tables - and it doesn't relate to
	###	any schedules - the command is being ignored and not
	###	translated to CTRL-M 'languague'.


}

###############
#SET CPUID by JOB
### Example: InsertOpprogSch BLCNFXTS  CUST    99      NULL    NULL
###          $command        $param1   $param2 $param3 $param4 $param5
sub InsertOpprogSch {
	### Keeping the CPU_ID for the SCHEDULE
	$SchCpuId{$param1} = $param2;
}

sub InsertOpparSch {
	### Example: InsertOpparSch  BLCONFIRM GROUP   BLCONFS NULL    NULL
	###          $command        $param1   $param2 $param3 $param4 $param5


	$JobBySchname{$param3}    = $param1;
	$Sch_GroupOrGlob{$param3} = $param2;

	$SchByJobname{$param1}    = $param3;
	$Job_GroupOrGlob{$param1} = $param2;

	### Keep the LastSchedule - in order to be able to track A's and B's
	###	for the following example:
	###
	###	InsertOpparSch BLPREP GROUP BLPREPBS NULL NULL
	###	InsertOpparSchFol BLPREP GROUP BLDUMPBS BLDUMPAU GROUP
	###
	$LastSchedule = $param3; 

	###
	### And ... get the CPU id for the job for the cycle
	### 
#	$CpuId = `GetCpuId.ksh $param1 $Cycle`; chomp($CpuId);
#	print "$param1 $CpuId\n";
#	exit;
}


###############
sub InsertOpprogSchFol {
	### Example: InsertOpprogSchFol BLCNFXTS  BLCHECKCS NULL    NULL    NULL
	###          $command           $param1   $param2   $param3 $param4 $param5

	$temp_dependency_list = $SchDependList{$param1};

	########
	### Add to the list - just in case the Schedule isn't on the list already 
	###		(there were duplications on the billing config files !!!)
	###

	if ($temp_dependency_list !~ /$param2 /) { $temp_dependency_list .= "$param2 "; }


	$SchDependList{$param1} = $temp_dependency_list;

#	print "for SCHED: $param1 - dep: $SchDependList{$param1}\n";

}


###############
sub InsertOpparSchFol {
	### Example: InsertOpparSchFol BLDEFREV  GROUP   BLCONFS BLCONFIRM GROUP
	###          $command          $param1   $param2 $param3 $param4   $param5

	###
	### Both jobs should run as GROUP in order to have dependency on the JOB_REC level - 
	### 	so, the 'valid' entries are :
	###		GROUP GROUP
	###		GROUP NEXTAAAA
	###		GROUP NEXTBBBB
	###
	###	while the following ones should be put as GROUP dependency (OPPROG_SCHFOL):
	###		GLOB GROUP
	###		GLOB NEXTAAAA
	###		GLOB NEXTBBBB


	if (($param2 =~ /GLOB/) || ($param5 =~ /GLOB/)) {
		print "Mistake in Dependency - InsertOpparSchFol for  $param1 dep on $param3\n";
		### We have to get the SCHEDULE name for the JOB apears as $param1 - 
		###	this is done, using the previously saved: $LastSchedule
		$param1  = $LastSchedule;
		$param2  = $param3;
		&InsertOpprogSchFol ();
	} else {

		### As the dependency is on the JOB level - 
		###	and as there are A's and B's schedules for jobs having the SAME job name,
		###	in order to be able to know to which sched to relate the job - 
		###	we keep the dependency with both the schedule name as well as the job name.
		###
		###	example:
		###	InsertOpparSchFol BLPREP GROUP BLDUMPBS BLDUMPAU GROUP
		###	
		###	the schedule was kept in $LastSchedule, and it will be saved as:
		###	BLDUMPBS_BLDUMPAU for the following :  BLPREPBS_BLPREP
		$related_job    = "${LastSchedule}_${param1}";
		$new_dependency = "${param3}_${param4}";

		$temp_dependency_list = $JobDependList{$related_job};

		########
		### Check whether to append a blank to the dependency list or not (in case it is 
		###		the first dependency in the list ...
		###
		if ($temp_dependency_list =~ /^$/) {
			$temp_dependency_list = $new_dependency;
		} else {
			$temp_dependency_list .= " $new_dependency";
		}

		$JobDependList{$related_job} = $temp_dependency_list;

#		print "for JOB: $related_job - dep: $JobDependList{$related_job}\n";
	}
		

}

###############
sub FillTableField {
	### Example: FillTableField BLTBMAINT NULL    1       V       NULL
	###          $command       $param1   $param2 $param3 $param4 $param5

}

###############
sub UpdateLoopIndicatr {

	### This set the InsideLoopIndctr (indicator) - 
	### 	so - if required - one can check whether a command
	###	is running as parallel (GROUP), inside a FOR/NEXT loop, or
	###	as single (GLOB).
	### 
	###	So, everytime the script enters a loop (in the config file),
	###	hence - meeting the FOR command - it sets the indicator to 1 - not(0),
	###	and when it meets the NEXT command - it sets it back to 0 - not(1).

	$InsideLoopIndctr = (! $InsideLoopIndctr);

	### Keep A's and B's per schedule
	if ($command =~ /NEXT/) { $SchType{$LastSchedule} = $param2; }

}

###############
sub DoNothing {

	### This is the part where the lines that do NOT contain any commands
	###	within the config file - are ignored.
	### 	YET, if one would like to report of them or to check them - 
	###	this is the subroutine where it can be done ...

}

sub Create_SubTables_Files {
	###
	foreach $OLD_SchName (keys %JobBySchname) {

		if      ($SchType{$OLD_SchName} =~ /AAAA/) { $SchType = 'Axx'; $SchTypeChar = 'A';} 
		elsif   ($SchType{$OLD_SchName} =~ /BBBB/) { $SchType = 'Bxx'; $SchTypeChar = 'B';} 
		else 				      { $SchType = 'G00'; $SchTypeChar = 'G';} 

		#$RelatedJob=$JobBySchname{$OLD_SchName};
		$RelatedJob=$OLD_SchName;
		$NEW_SchName = "${Proj}_${RelatedJob}_${SchTypeChar}";

		open  (SCHED_FILE,">${output_dir}/${NEW_SchName}");

		print SCHED_FILE "<SUB_TABLE \n";
		print SCHED_FILE "APPLICATION=\"" . $ApplicationName . "\"\n";
		print SCHED_FILE "GROUP=\"" . $ApplicationName . "\"\n";
		print SCHED_FILE "AUTHOR=\"billing\"\n";
		print SCHED_FILE "JOBNAME=\"" . $NEW_SchName . "\"\>\n";
		print SCHED_FILE "<RULE_BASED_CALENDARS NAME=\"*\" />\n";
		print SCHED_FILE "</SUB_TABLE>";
        close (SCHED_FILE);
	}
}

###############
sub Create_SubTable_Dependencies {
	###
	foreach $OLD_SchName (keys %JobBySchname) {

	   if      ($SchType{$OLD_SchName} =~ /AAAA/) { $SchType = 'Axx'; $SchTypeChar = 'A';} 
	   elsif   ($SchType{$OLD_SchName} =~ /BBBB/) { $SchType = 'Bxx'; $SchTypeChar = 'B';} 
	   else 				      { $SchType = 'G00'; $SchTypeChar = 'G';} 

		#$RelatedJob=$JobBySchname{$OLD_SchName};
		$RelatedJob=$OLD_SchName;
		
	   $NEW_SchName = "${Proj}_${RelatedJob}_${SchTypeChar}";
	   
		my $SCHED_FILE_parse = XML::LibXML->new();
		my $SCHED_FILE = $SCHED_FILE_parse->parse_file("${output_dir}/${NEW_SchName}");
	   $SCHED_FILE_Sub = $SCHED_FILE->documentElement;
	   ### 
	   ###  Put the dependcy list of the SCHEDULE into variable - $Depende_Sched_list
	   $Depende_Sched_list = $SchDependList{$OLD_SchName};
	   ###  and now - into an array, where every cell contains a schedule that OUR current one is depend on ...
	   @Depende_Sched_list = (split(/\s+/, $Depende_Sched_list));

		#	print "For SCHED:$OLD_SchName  dep: $Depende_Sched_list \n";

	   for ($curr_cell_ind=0;$curr_cell_ind <= $#Depende_Sched_list ; $curr_cell_ind++) {
		   $DependSchName = $Depende_Sched_list[$curr_cell_ind];

	   	   #$CurrJob=$JobBySchname{$DependSchName};
		   $CurrJob=$DependSchName;

		   if      ($SchType{$DependSchName} =~ /AAAA/) { $DepSchType = 'A'; $DepSchTypeChar = 'A';} 
	 	   elsif   ($SchType{$DependSchName} =~ /BBBB/) { $DepSchType = 'B'; $DepSchTypeChar = 'B';} 
	   	   else 				      	{ $DepSchType = 'G00'; $DepSchTypeChar = 'G';} 

	        $FULL_DependSchName = "${Proj}_${CurrJob}_${DepSchTypeChar}";

		   #print SCHED_FILE " \\\n";
		   
		   $INCOND = $SCHED_FILE_parse->parse_balanced_chunk("<INCOND NAME=\"${NEW_SchName}__FOL__${FULL_DependSchName}-${ApplicationName}-OK\" ODATE=\"ODAT\" />\n");
		   $OUTCONDREM = $SCHED_FILE_parse->parse_balanced_chunk("<OUTCOND NAME=\"${NEW_SchName}__FOL__${FULL_DependSchName}-${ApplicationName}-OK\" ODATE=\"ODAT\" SIGN=\"DEL\" />\n");
		   $SCHED_FILE_Sub -> appendChild($INCOND);
		   $SCHED_FILE_Sub -> appendChild($OUTCONDREM);
		  
		   #print SCHED_FILE "-INCOND ${NEW_SchName}__FOL__${FULL_DependSchName}-${ApplicationName}-OK ODAT AND";
			my $DEPEND_SCHED_FILE_parse = XML::LibXML->new();
			my $DEPEND_SCHED_FILE = $DEPEND_SCHED_FILE_parse->parse_file("${output_dir}/${FULL_DependSchName}");
		    $DEPEND_SCHED_FILE_Sub = $DEPEND_SCHED_FILE->documentElement;

			#open  (DEPEND_SCHED_FILE,">>${output_dir}/${FULL_DependSchName}");

		   $OUTCONDADD = $DEPEND_SCHED_FILE_parse->parse_balanced_chunk("<OUTCOND NAME=\"${NEW_SchName}__FOL__${FULL_DependSchName}-${ApplicationName}-OK\" ODATE=\"ODAT\" SIGN=\"ADD\" />\n");
		   $DEPEND_SCHED_FILE_Sub -> appendChild($OUTCONDADD);
		  
		   #print DEPEND_SCHED_FILE "-OUTCOND ${NEW_SchName}__FOL__${FULL_DependSchName}-${ApplicationName}-OK ODAT ADD";
			open  (DEPEND_SCHED_FILE,">${output_dir}/${FULL_DependSchName}");
			print DEPEND_SCHED_FILE $DEPEND_SCHED_FILE_Sub;
			close (DEPEND_SCHED_FILE);
	   

	   }
	   open  (SCHED_FILE,">${output_dir}/${NEW_SchName}");
	   print SCHED_FILE $SCHED_FILE_Sub;
	   close (SCHED_FILE);
	   
	}
}


###############
sub Create_Jobs_Files {
	###
	###  in the Associative array - JobDependList - the entries look like the following one:
	###
	###  	BLPREPBS_BLPREP  (Sched_Job)
	foreach $OLD_SchName (keys %JobBySchname) {

	   $RelatedJob = $JobBySchname{$OLD_SchName};
	   

		if      ($SchType{$OLD_SchName} =~ /AAAA/) { $SchType = 'A'; $JobType = 'A'; $TypeChar = 'A'; } 
		elsif   ($SchType{$OLD_SchName} =~ /BBBB/) { $SchType = 'B'; $JobType = 'B'; $TypeChar = 'B'; } 
		else    { $SchType = 'G00'; $JobType = 'G00'; $TypeChar = 'G'; } 

		$NEW_SchName    = "${Proj}_${OLD_SchName}_${TypeChar}";		### Example:  V21_BLDUMPAU_A
		$FullJobRec     = "${BillCycleCode}${JobType}";			### Example:  B05122010A%%


		if ($SchType ne 'G00') {
		
			for ($par=1; $par <= $ProdParallel ; $par++) { 
			
				if ($par < 10) {
					$StdrdJobName   = "${Proj}_${RelatedJob}_${BillCycleNoYearCode}${SchType}0${par}";		### Example:  V21_BLDUMPAU_C99R31A%%
					$CtrlMJobName   = "${Proj}_${RelatedJob}_${FullJobRec}0${par}R${Rerun_NO}";	### Example:  V21_BLDUMPAU_B05122010A%%R01 
				}
				else {
					$StdrdJobName   = "${Proj}_${RelatedJob}_${BillCycleNoYearCode}${SchType}${par}";		### Example:  V21_BLDUMPAU_C99R31A%%
					$CtrlMJobName   = "${Proj}_${RelatedJob}_${FullJobRec}${par}R${Rerun_NO}";	### Example:  V21_BLDUMPAU_B05122010A%%R01 
				}
				
				open  (JOB_FILE,">${output_dir}/${StdrdJobName}");
				print JOB_FILE "<JOB \n";
				print JOB_FILE "APPLICATION=\"" . $ApplicationName . "\"\n";
				print JOB_FILE "GROUP=\"" . $NEW_SchName . "\"\n";
				print JOB_FILE "DESCRIPTION=\"" . $NEW_SchName . "\"\n";
				print JOB_FILE "JOBNAME=\"" . $StdrdJobName . "\"\n";
				print JOB_FILE "MEMNAME=\"" . $CtrlMJobName . "\"\n";
				print JOB_FILE "NODEID=\"" . ${RelatedJob} . "_" .${FullJobRec} . "_" . ${CpuCycleCode} . "_CPU\"\n";
				print JOB_FILE "OWNER=\"oper\" \n";
				print JOB_FILE "TASKTYPE=\"Command\" \n";
				print JOB_FILE "CMDLINE=\"OPSYS_OprunScript " . ${RelatedJob} . " " . $FullJobRec . " CAN 1 0 D '' ''\"";
				print JOB_FILE "\>\n"; 	   
				print JOB_FILE "<QUANTITATIVE NAME=\"" . $ApplicationName . "\" QUANT=\"1\" />\n";
				print JOB_FILE "<SHOUT DEST=\"EM\" TIME=\"+025%\" URGENCY=\"U\" WHEN=\"EXECTIME\" MESSAGE=\"%%JOBNAME is running 25% longer than its average time\" />\n";

				print JOB_FILE "</JOB>";

				close (JOB_FILE);
		   }
		}
		
		else 
		{
			$StdrdJobName   = "${Proj}_${RelatedJob}_${BillCycleNoYearCode}${SchType}";
			$CtrlMJobName   = "${Proj}_${RelatedJob}_${FullJobRec}R${Rerun_NO}";
			open  (JOB_FILE,">${output_dir}/${StdrdJobName}");
			print JOB_FILE "<JOB \n";
			print JOB_FILE "APPLICATION=\"" . $ApplicationName . "\"\n";
			print JOB_FILE "GROUP=\"" . $NEW_SchName . "\"\n";
			print JOB_FILE "DESCRIPTION=\"" . $NEW_SchName . "\"\n";
			print JOB_FILE "JOBNAME=\"" . $StdrdJobName . "\"\n";
			print JOB_FILE "MEMNAME=\"" . $CtrlMJobName . "\"\n";
			print JOB_FILE "NODEID=\"" . ${RelatedJob} . "_" .${FullJobRec} . "_" . ${CpuCycleCode} . "_CPU\"\n";
			print JOB_FILE "OWNER=\"oper\" \n";
			print JOB_FILE "TASKTYPE=\"Command\" \n";
			print JOB_FILE "CMDLINE=\"OPSYS_OprunScript " . ${RelatedJob} . " " . $FullJobRec . " CAN 1 0 D '' ''\"";
			print JOB_FILE "\>\n"; 	   
			print JOB_FILE "<QUANTITATIVE NAME=\"" . $ApplicationName . "\" QUANT=\"1\" />\n";
			print JOB_FILE "<SHOUT DEST=\"EM\" TIME=\"+025%\" URGENCY=\"U\" WHEN=\"EXECTIME\" MESSAGE=\"%%JOBNAME is running 25% longer than its average time\" />\n";

			print JOB_FILE "</JOB>";

			close (JOB_FILE);
		}
	}
}



###############################
sub Create_Jobs_Dependencies {

	foreach $SchName_JobName (keys %JobDependList) {

	   ($OLD_SchName,$RelatedJob)=(split(/_/,$SchName_JobName));

	   if      ($SchType{$OLD_SchName} =~ /AAAA/) { $SchType = 'A'; $SchTypeChar = 'A'; $JobType = 'A%%';} 
	   elsif   ($SchType{$OLD_SchName} =~ /BBBB/) { $SchType = 'B'; $SchTypeChar = 'B'; $JobType = 'B%%';} 
	   else  { $SchType = 'G00'; $SchTypeChar = 'G'; $JobType = 'G00';} 

	   $StdrdJobName   = "${Proj}_${RelatedJob}_${BillCycleNoYearCode}R${Rerun_NO}${SchType}";		### Example:  V21_BLDUMPAU_B12A%%
	   
	   #if jobA is a parallel, and Jobb is a parrelel match parallelA to other parallelA 
	   #else if jobA is a parallel and JobB is group, match all parallels to the group
	   # if jobA is a group and jobB is a parallel, match group to all parallels
	   #if jobA is a group and JobB is a group, match group to group
	   
		if ($SchType ne 'G00') {
	
			for ($par=1; $par <= $ProdParallel ; $par++) { 
			
				if ($par < 10) {
					$StdrdJobName   = "${Proj}_${RelatedJob}_${BillCycleNoYearCode}${SchType}0${par}";		### Example:  V21_BLDUMPAU_C99R31A%%			 
				}
				else {
					$StdrdJobName   = "${Proj}_${RelatedJob}_${BillCycleNoYearCode}${SchType}${par}";		### Example:  V21_BLDUMPAU_C99R31A%%
				}
			   
				$temp_dependency_list = $JobDependList{$SchName_JobName};
				@JobDependList = (split(/\s+/ , $temp_dependency_list));

				my $JOB_FILE_parse = XML::LibXML->new();
				my $JOB_FILE = $JOB_FILE_parse->parse_file("${output_dir}/${StdrdJobName}");
				#open  (JOB_FILE,">>${output_dir}/${StdrdJobName}");

				for ($curr_cell_ind=0;$curr_cell_ind <= $#JobDependList ; $curr_cell_ind++) {
					($DepSchName,$DepJobName) = (split(/_/ , $JobDependList[$curr_cell_ind]));

					if      ($SchType{$DepSchName} =~ /AAAA/) { $DepSchType = 'A'; $DepSchTypeChar = 'A'; $DepJobType = 'A';} 
					elsif   ($SchType{$DepSchName} =~ /BBBB/) { $DepSchType = 'B'; $DepSchTypeChar = 'B'; $DepJobType = 'B';} 
					else 				     { $DepSchType = 'G00'; $DepSchTypeChar = 'G'; $DepJobType = 'G00';} 

					#parallelA/B to parallelA/B - Should only match once
					if ($DepSchType ne 'G00') {
						for ($deppar=1; $deppar <= $ProdParallel ; $deppar++) { 
							if ($par == $deppar) {
								if ($par < 10) {
									$StdrdDepJobName   = "${Proj}_${DepJobName}_${BillCycleNoYearCode}${DepSchType}0${deppar}";		### Example:  V21_BLDUMPAU_B05122010A%%
								}
								else {
									$StdrdDepJobName   = "${Proj}_${DepJobName}_${BillCycleNoYearCode}${DepSchType}${deppar}";		### Example:  V21_BLDUMPAU_B05122010A%%
								}
							}
						}
						#print JOB_FILE " \\\n";
						$JOB_FILE_job = $JOB_FILE->documentElement;
						$INCOND = $JOB_FILE_parse->parse_balanced_chunk("<INCOND NAME=\"${StdrdJobName}__FOL__${StdrdDepJobName}-${ApplicationName}-OK\" ODATE=\"ODAT\" />\n");
						$OUTCONDREM = $JOB_FILE_parse->parse_balanced_chunk("<OUTCOND NAME=\"${StdrdJobName}__FOL__${StdrdDepJobName}-${ApplicationName}-OK\" ODATE=\"ODAT\" SIGN=\"DEL\" />\n");
						$JOB_FILE_job -> appendChild($INCOND);
						$JOB_FILE_job -> appendChild($OUTCONDREM);

						my $DEPEND_JOB_FILE_parse = XML::LibXML->new();
						my $DEPEND_JOB_FILE = $DEPEND_JOB_FILE_parse->parse_file("${output_dir}/${StdrdDepJobName}");
						$DEPEND_JOB_FILE_job = $DEPEND_JOB_FILE->documentElement;

						$OUTCONDADD = $DEPEND_JOB_FILE_parse->parse_balanced_chunk("<OUTCOND NAME=\"${StdrdJobName}__FOL__${StdrdDepJobName}-${ApplicationName}-OK\" ODATE=\"ODAT\" SIGN=\"ADD\" />\n");
						$DEPEND_JOB_FILE_job -> appendChild($OUTCONDADD);

						open  (DEPEND_JOB_FILE,">${output_dir}/${StdrdDepJobName}");
						print DEPEND_JOB_FILE $DEPEND_JOB_FILE_job;
						close (DEPEND_JOB_FILE);
					   
						open  (JOB_FILE,">${output_dir}/${StdrdJobName}");
						print JOB_FILE $JOB_FILE_job;
						close (JOB_FILE);

					}
					#parallelA/B to group - create from sub table to job
					else 
					{
						$DepSubName = "${Proj}_${DepSchName}_${DepSchType}";
						#$StdrdDepJobName   = "${Proj}_${DepJobName}_${BillCycleNoYearCode}${DepSchType}";
						
						$JOB_FILE_job = $JOB_FILE->documentElement;
						$INCOND = $JOB_FILE_parse->parse_balanced_chunk("<INCOND NAME=\"${StdrdJobName}__FOL__${StdrdDepJobName}-${ApplicationName}-OK\" ODATE=\"ODAT\" />\n");
						$OUTCONDREM = $JOB_FILE_parse->parse_balanced_chunk("<OUTCOND NAME=\"${StdrdJobName}__FOL__${StdrdDepJobName}-${ApplicationName}-OK\" ODATE=\"ODAT\" SIGN=\"DEL\" />\n");
						$JOB_FILE_job -> appendChild($INCOND);
						$JOB_FILE_job -> appendChild($OUTCONDREM);

						my $DEPEND_SUB_FILE_parse = XML::LibXML->new();
						my $DEPEND_SUB_FILE = $DEPEND_SUB_FILE_parse->parse_file("${output_dir}/${DepSubName}");
						$DEPEND_SUB_FILE_job = $DEPEND_SUB_FILE->documentElement;

						$OUTCONDADD = $DEPEND_SUB_FILE_parse->parse_balanced_chunk("<OUTCOND NAME=\"${StdrdJobName}__FOL__${DepSubName}-${ApplicationName}-OK\" ODATE=\"ODAT\" SIGN=\"ADD\" />\n");
						$DEPEND_SUB_FILE_job -> appendChild($OUTCONDADD);

						open  (DEPEND_SUB_FILE,">${output_dir}/${DepSubName}");
						print DEPEND_SUB_FILE $DEPEND_SUB_FILE_job;
						close (DEPEND_SUB_FILE);
					   
						open  (JOB_FILE,">${output_dir}/${StdrdJobName}");
						print JOB_FILE $JOB_FILE_job;
						close (JOB_FILE);
					}
				}
			}
		}
		else 
		{
			$StdrdJobName   = "${Proj}_${RelatedJob}_${BillCycleNoYearCode}${SchType}";
			
			$temp_dependency_list = $JobDependList{$SchName_JobName};
			@JobDependList = (split(/\s+/ , $temp_dependency_list));

			my $JOB_FILE_parse = XML::LibXML->new();
			my $JOB_FILE = $JOB_FILE_parse->parse_file("${output_dir}/${StdrdJobName}");
			
			for ($curr_cell_ind=0;$curr_cell_ind <= $#JobDependList ; $curr_cell_ind++) {
				($DepSchName,$DepJobName) = (split(/_/ , $JobDependList[$curr_cell_ind]));

				if      ($SchType{$DepSchName} =~ /AAAA/) { $DepSchType = 'A'; $DepSchTypeChar = 'A'; $DepJobType = 'A';} 
				elsif   ($SchType{$DepSchName} =~ /BBBB/) { $DepSchType = 'B'; $DepSchTypeChar = 'B'; $DepJobType = 'B';} 
				else 				     { $DepSchType = 'G00'; $DepSchTypeChar = 'G'; $DepJobType = 'G00';} 
				
				#group to parallelA/B
				if ($DepSchType ne 'G00') {
					for ($deppar=1; $deppar <= $ProdParallel ; $deppar++) { 
						if ($par == $deppar) {
							if ($par < 10) {
								$StdrdDepJobName   = "${Proj}_${DepJobName}_${BillCycleNoYearCode}${DepSchType}0${deppar}";		### Example:  V21_BLDUMPAU_B05122010A%%
							}
							else {
								$StdrdDepJobName   = "${Proj}_${DepJobName}_${BillCycleNoYearCode}${DepSchType}${deppar}";		### Example:  V21_BLDUMPAU_B05122010A%%
							}
						}				
						#print JOB_FILE " \\\n";
						$JOB_FILE_job = $JOB_FILE->documentElement;
						$INCOND = $JOB_FILE_parse->parse_balanced_chunk("<INCOND NAME=\"${StdrdJobName}__FOL__${StdrdDepJobName}-${ApplicationName}-OK\" ODATE=\"ODAT\" />\n");
						$OUTCONDREM = $JOB_FILE_parse->parse_balanced_chunk("<OUTCOND NAME=\"${StdrdJobName}__FOL__${StdrdDepJobName}-${ApplicationName}-OK\" ODATE=\"ODAT\" SIGN=\"DEL\" />\n");
						$JOB_FILE_job -> appendChild($INCOND);
						$JOB_FILE_job -> appendChild($OUTCONDREM);

						my $DEPEND_JOB_FILE_parse = XML::LibXML->new();
						my $DEPEND_JOB_FILE = $DEPEND_JOB_FILE_parse->parse_file("${output_dir}/${StdrdDepJobName}");
						$DEPEND_JOB_FILE_job = $DEPEND_JOB_FILE->documentElement;

						$OUTCONDADD = $DEPEND_JOB_FILE_parse->parse_balanced_chunk("<OUTCOND NAME=\"${StdrdJobName}__FOL__${StdrdDepJobName}-${ApplicationName}-OK\" ODATE=\"ODAT\" SIGN=\"ADD\" />\n");
						$DEPEND_JOB_FILE_job -> appendChild($OUTCONDADD);

						open  (DEPEND_JOB_FILE,">${output_dir}/${StdrdDepJobName}");
						print DEPEND_JOB_FILE $DEPEND_JOB_FILE_job;
						close (DEPEND_JOB_FILE);
					   
						open  (JOB_FILE,">${output_dir}/${StdrdJobName}");
						print JOB_FILE $JOB_FILE_job;
						close (JOB_FILE);
					}			
				}
				#group to group
				else 
				{
					$StdrdDepJobName   = "${Proj}_${DepJobName}_${BillCycleNoYearCode}${DepSchType}";
										
					$JOB_FILE_job = $JOB_FILE->documentElement;
					$INCOND = $JOB_FILE_parse->parse_balanced_chunk("<INCOND NAME=\"${StdrdJobName}__FOL__${StdrdDepJobName}-${ApplicationName}-OK\" ODATE=\"ODAT\" />\n");
					$OUTCONDREM = $JOB_FILE_parse->parse_balanced_chunk("<OUTCOND NAME=\"${StdrdJobName}__FOL__${StdrdDepJobName}-${ApplicationName}-OK\" ODATE=\"ODAT\" SIGN=\"DEL\" />\n");
					$JOB_FILE_job -> appendChild($INCOND);
					$JOB_FILE_job -> appendChild($OUTCONDREM);

					my $DEPEND_JOB_FILE_parse = XML::LibXML->new();
					my $DEPEND_JOB_FILE = $DEPEND_JOB_FILE_parse->parse_file("${output_dir}/${StdrdDepJobName}");
					$DEPEND_JOB_FILE_job = $DEPEND_JOB_FILE->documentElement;

					$OUTCONDADD = $DEPEND_JOB_FILE_parse->parse_balanced_chunk("<OUTCOND NAME=\"${StdrdJobName}__FOL__${StdrdDepJobName}-${ApplicationName}-OK\" ODATE=\"ODAT\" SIGN=\"ADD\" />\n");
					$DEPEND_JOB_FILE_job -> appendChild($OUTCONDADD);

					open  (DEPEND_JOB_FILE,">${output_dir}/${StdrdDepJobName}");
					print DEPEND_JOB_FILE $DEPEND_JOB_FILE_job;
					close (DEPEND_JOB_FILE);
				   
					open  (JOB_FILE,">${output_dir}/${StdrdJobName}");
					print JOB_FILE $JOB_FILE_job;
					close (JOB_FILE);
				}
			}

		}
	}
}

sub Create_XML_FileForDelivery {

	my %sub_table_hash;
	

	#ADD ALL JOBS to THEIR SUB TABLES
	foreach $OLD_SchName (keys %JobBySchname) {

		if      ($SchType{$OLD_SchName} =~ /AAAA/) { $SchType = 'A'; $SchTypeChar = 'A';} 
		elsif   ($SchType{$OLD_SchName} =~ /BBBB/) { $SchType = 'B'; $SchTypeChar = 'B';} 
		else 				      { $SchType = 'G00'; $SchTypeChar = 'G';} 

		$RelatedJob=$JobBySchname{$OLD_SchName};
		
		
		#SUB TABLE NAME
		$NEW_SchName = "${Proj}_${OLD_SchName}_${SchTypeChar}";
		$sub_table_hash{$NEW_SchName} = 1;
		
		my $SUB_TABLE_parse = XML::LibXML->new();
		my $SUB_TABLE = $SUB_TABLE_parse->parse_file("${output_dir}/${NEW_SchName}");
		$SUB_TABLE_root = $SUB_TABLE->documentElement;
		
		#JOB NAME(S)
		if ($SchType ne 'G00')  {
			for ($par=1; $par <= $ProdParallel ; $par++) { 
				if ($par < 10) {
					$StdrdJobName   = "${Proj}_${RelatedJob}_${BillCycleNoYearCode}${SchType}0${par}";		### Example:  V21_BLDUMPAU_C99R31A%%			 
				}
				else {
					$StdrdJobName   = "${Proj}_${RelatedJob}_${BillCycleNoYearCode}${SchType}${par}";		### Example:  V21_BLDUMPAU_C99R31A%%
				}	

				my $JOB_parse = XML::LibXML->new();
				my $JOB = $JOB_parse->parse_file("${output_dir}/${StdrdJobName}");
				$JOB_root = $JOB->documentElement;				
				$SUB_TABLE_root->appendChild($JOB_root);
			}
		}
		else {
			$StdrdJobName   = "${Proj}_${RelatedJob}_${BillCycleNoYearCode}${SchType}";
			my $JOB_parse = XML::LibXML->new();
			my $JOB = $JOB_parse->parse_file("${output_dir}/${StdrdJobName}");
			$JOB_root = $JOB->documentElement;				
			$SUB_TABLE_root->appendChild($JOB_root);
		}

		open  (SUB_TABLE_FILE,">${output_dir}/${NEW_SchName}");
		print SUB_TABLE_FILE $SUB_TABLE_root;
		close (SUB_TABLE_FILE);
		
		#print "\n\n\ Cleanup Job Files ${output_dir}/${StdrdJobName}\n\n";
		#system ("del ${output_dir}\\${StdrdJobName}") ;
	}
	
		#create SMART Table
	
	open  (SMART_FILE,">${output_dir}/${SmartTable}");
	
	print SMART_FILE "<?xml version='1.0' encoding='ISO-8859-1' ?> \n";
	print SMART_FILE "<!DOCTYPE DEFTABLE SYSTEM \"deftable.dtd\"> \n";
	print SMART_FILE "<DEFTABLE> \n";
	
	print SMART_FILE "<SMART_TABLE \n";
	print SMART_FILE "APPLICATION=\"" . $ApplicationName . "\"\n";
	print SMART_FILE "DATACENTER=\"controlmdemo\" \n";
	print SMART_FILE "GROUP=\"" . $ApplicationName . "\" \n";
	print SMART_FILE "AUTHOR=\"billing\"\n";
	print SMART_FILE "JOBNAME=\"" . $SmartTable . "\"\n";
	print SMART_FILE "TABLE_NAME=\"" . $SmartTable . "\"\>\n";
	print SMART_FILE "<RULE_BASED_CALENDAR NAME=\"NONE\" />\n";
	
	
	foreach $sub_table (keys %sub_table_hash)
	{
		my $SUB_TABLE_parse = XML::LibXML->new();
		my $SUB_TABLE_doc = $SUB_TABLE_parse->parse_file("${output_dir}/${sub_table}");
	    $SUB_TABLE_root = $SUB_TABLE_doc->documentElement;
		
		print SMART_FILE  $SUB_TABLE_root . "\n";
		
		#system ("del ${output_dir}\\${sub_table}") ;
	}

	print SMART_FILE "</SMART_TABLE>";
	print SMART_FILE "</DEFTABLE>";

    close (SMART_FILE);
	#ADD SUBS to SMART
}