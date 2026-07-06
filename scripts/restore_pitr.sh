#!/bin/bash
export ORACLE_SID=ORADB
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH

LOG_FILE=/path/logs/restore_pitr_$(date +%Y%m%d_%H%M%S).log

rman log=$LOG_FILE << EOF
CONNECT TARGET /
CONNECT CATALOG user/pass@catalog

RUN {
    SET UNTIL TIME "TO_DATE('2026-05-20 23:59:00','YYYY-MM-DD HH24:MI:SS')";
    RESTORE DATABASE;
    RECOVER DATABASE;
}
EOF

if [ $(cat $LOG_FILE | grep -c "ORA-") -eq "0" ]; then
    echo "Restore/Recover completado sin errores ORA-"
else
    echo "Errores ORA- detectados, revisar: $LOG_FILE"
fi
