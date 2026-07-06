-- Solo recopilar estadísticas del índice nuevo
BEGIN
    DBMS_STATS.GATHER_INDEX_STATS(
        ownname    => 'EXNHM1',
        indname    => 'HM_FINAL_CONTRATOS_FINAL_GRP_IDX',
        estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
        degree     => 16
    );
END;
/
