#!/bin/sh
#######################################################################
# Initialization:

#: ${OCF_FUNCTIONS_DIR=${OCF_ROOT}/lib/custom}
#. ${OCF_FUNCTIONS_DIR}/ocf-shellfuncs

if [ -z "$OCF_ROOT" ]; then
    : ${OCF_ROOT=/usr/lib/ocf}
fi

if [ "$OCF_FUNCTIONS_DIR" = ${OCF_ROOT}/resource.d/heartbeat ]; then  # old
        unset OCF_FUNCTIONS_DIR
fi

: ${OCF_FUNCTIONS_DIR:=${OCF_ROOT}/lib/heartbeat}

. ${OCF_FUNCTIONS_DIR}/ocf-binaries
. ${OCF_FUNCTIONS_DIR}/ocf-returncodes
. ${OCF_FUNCTIONS_DIR}/ocf-directories
. ${OCF_FUNCTIONS_DIR}/ocf-shellfuncs

#if test -n "${OCF_FUNCTIONS_DIR}" ; then
#        if test -e "${OCF_FUNCTIONS_DIR}/ocf-shellfuncs" ; then
#                . "${OCF_FUNCTIONS_DIR}/ocf-shellfuncs"
#        elif test -e "${OCF_FUNCTIONS_DIR}/.ocf-shellfuncs" ; then
#                . "${OCF_FUNCTIONS_DIR}/.ocf-shellfuncs"
#        fi
#else
#        if test -e "${OCF_ROOT}/lib/heartbeat/ocf-shellfuncs" ; then
#                . "${OCF_ROOT}/lib/heartbeat/ocf-shellfuncs"
#        elif test -e "${OCF_ROOT}/resource.d/heartbeat/.ocf-shellfuncs"; then
#                . "${OCF_ROOT}/resource.d/heartbeat/.ocf-shellfuncs"
#        fi
#fi

#######################################################################

meta_data() {
	cat <<END
<?xml version="1.0"?>
<!DOCTYPE resource-agent SYSTEM "ra-api-1.dtd">
<resource-agent name="asm-de" version="0.1">
<version>1.0</version>

<longdesc lang="en">

</longdesc>

<shortdesc lang="en">ASM DE Resource Agent</shortdesc>

<parameters>

<parameter name="srvctl" unique="0" required="true">
<longdesc lang="en">
Full path to the srvctl executable
</longdesc>
<shortdesc lang="en">srvctl Path</shortdesc>
<content type="string" default="/software/oracle/grid/12.1.0/bin/" />
</parameter>

<parameter name="mountasm" unique="0" required="true">
<longdesc lang="en">
Full path to the asm_disk_group_mount.ksh script
</longdesc>
<shortdesc lang="en">srvctl Path</shortdesc>
<content type="string" default="/prod/appl/oracle/ASM/scripts/" />
</parameter>

<parameter name="diskgroup" unique="0" required="true">
<longdesc lang="en">
The ASM disk group name
</longdesc>
<shortdesc lang="en">ASM disk group name</shortdesc>
<content type="string" default="" />
</parameter>

</parameters>

<actions>
<action name="start"        timeout="20s" />
<action name="stop"         timeout="20s" />
<action name="monitor"      timeout="20s" interval="10s" depth="0" />
<action name="validate-all" timeout="20s" />
<action name="meta-data"  timeout="5s"/>
</actions>
</resource-agent>
END
}

#######################################################################

USAGE="Usage: $0 {start|stop|monitor|status|validate-all|meta-data}";

asm_usage() {
	echo $USAGE >&2
}

asm_status() {
	# Monitor _MUST!_ differentiate correctly between running
	# (SUCCESS), failed (ERROR) or _cleanly_ stopped (NOT RUNNING).
	# That is THREE states, not just yes/no.
	status=""
	cnt=0
	for word in $($OCF_RESKEY_srvctl/srvctl status diskgroup -diskgroup $OCF_RESKEY_diskgroup)
	do
		if [ $cnt = 0 ]
		then
			status="$word"
		elif [ $cnt -lt 5 ]
		then
			status="$status $word"
		else
			break
		fi
		cnt=$((cnt+1))
	done

	if [ "$status" = "Disk Group $OCF_RESKEY_diskgroup is running" ]
	then
		return $OCF_SUCCESS
	elif [ "$status" = "Disk Group $OCF_RESKEY_diskgroup is stopped" ]
	then
		return $OCF_NOT_RUNNING
	else
		return $OCF_ERR_GENERIC
	fi
}

asm_start() {
	rc=asm_status
    if [ $rc -eq $OCF_SUCCESS ]; then
		return $OCF_SUCCESS
    elif [ $rc -ne $OCF_NOT_RUNNING ]; then
		ocf_exit_reason "Error. Unknown status."
		exit $OCF_ERR_GENERIC
    fi

	ocf_log info "Mounting ASM Disk Group $OCF_RESKEY_diskgroup..."
	ocf_run "$OCF_RESKEY_mountasm/asm_disk_group_mount.ksh $OCF_RESKEY_diskgroup"

	rc=asm_status
    if [ $rc -eq $OCF_SUCCESS ]; then
		ocf_log info "Mounted ASM Disk Group $OCF_RESKEY_diskgroup"
		return $OCF_SUCCESS
    elif [ $rc -ne $OCF_NOT_RUNNING ]; then
		ocf_exit_reason "Error. Unknown status."
		exit $OCF_ERR_GENERIC
    fi
}

asm_stop() {
	if asm_status; then
		ocf_log info "Un-Mounting ASM Disk Group $OCF_RESKEY_diskgroup..."
		ocf_run "$OCF_RESKEY_srvctl/srvctl stop diskgroup -diskgroup $OCF_RESKEY_diskgroup"
		ocf_log info "Un-Mounted ASM Disk Group $OCF_RESKEY_diskgroup"
		return $OCF_SUCCESS
	fi
}

asm_validate() {
	asm_status
	return $OCF_SUCCESS
}

#####
#
#MAIN
#
#####

if [ $# -ne 1 ]; then
        asm_usage
        exit $OCF_ERR_ARGS
fi


case $1 in
	start)  
        asm_start
    ;;
    stop)
        asm_stop
    ;;
    status) 
		asm_status
    ;;
    monitor)
		asm_status
    ;;
    validate-all)
        asm_validate
    ;;
    meta-data)    
		meta_data
    ;;
    usage)  
		asm_usage
        exit $OCF_SUCCESS
    ;;
    *)
    	asm_usage
        exit $OCF_ERR_UNIMPLEMENTED
    ;;
esac