-- Convert the restored SAI copy to utf8mb4 without a second encoding pass.
--
-- Source: base_20261027.tgz (mysqldump 10.14, MariaDB 5.5.52, 27 Oct 2026).
-- Do not run this against production. Run it once, with the mysql client,
-- against a copy imported from that dump.
--
-- Import (the dump already contains SET NAMES utf8; the client must read the
-- file as utf8 or it will encode those bytes again):
--   mysql --default-character-set=utf8 -u USER -p -e \
--     "CREATE DATABASE sai CHARACTER SET latin1 COLLATE latin1_swedish_ci;
--      CREATE DATABASE tabgralessai CHARACTER SET latin1 COLLATE latin1_swedish_ci;
--      CREATE DATABASE tabgrales2 CHARACTER SET utf8 COLLATE utf8_general_ci;"
--   mysql --default-character-set=utf8 -u USER -p sai < sai_db.sql
--   mysql --default-character-set=utf8 -u USER -p tabgralessai < tabgralessai_db.sql
--   mysql --default-character-set=utf8 -u USER -p tabgrales2 < tabgrales2_db.sql
--
-- Then:
--   mysql --default-character-set=utf8mb4 -u USER -p < scripts/convert_utf8mb4.sql
--
-- Why the bytes are not what the dump file shows
-- sai and tabgralessai tables are latin1. SET NAMES utf8 made the dump client
-- turn a real latin1 E1 (a-acute) into the file bytes C3 A1. That majority is
-- one correct conversion. ALTER ... CONVERT TO utf8mb4 does that same step
-- once and must not be fed the dump text a second time.
-- A leftover was already UTF-8 inside the latin1 column. The dump client
-- encoded it again, so the file shows C3 83 C2 xx (C3 lead) or C3 82 C2 xx
-- (C2 lead). After a faithful import the table still holds the raw pair
-- (C3 B3 for o-acute, C2 BA for masculine ordinal, ...). This script replaces
-- only those pairs with the single latin1 byte, then converts the column.
-- It does not reinterpret the whole value: the same strings also contain
-- real latin1 accents, and a whole-value cast would corrupt them.
-- Three UTF-8 sequences do not fit in latin1 (EF BF BD, EF B9 A5, EF BB BF).
-- They are put back together after the conversion. Doing it before would
-- store a character latin1 cannot hold. Doing neither would turn EF BF BD
-- into the three characters U+00EF U+00BF U+00BD.
-- tabgrales2 is already utf8. Its tables are widened to utf8mb4. They are
-- never read as latin1.
--
-- Counts in column values (not table comments):
--   double sequences repaired before convert: 5278
--   utf-8 sequences outside latin1, repaired after convert: 10148
--   character columns repaired: 5 (all in sai)
--   latin1 character columns converted with no repair: 317
--   utf8 character columns widened: 73 (tabgrales2)
-- Table comments carry 28 more double sequences. They are rewritten below.
-- Foreign keys are dropped before CONVERT and added back afterward (MariaDB error 1832).
-- sessions.SessionID and stored_procedures.spnombre are varchar(255) keys.
-- utf8mb4 makes those indexes 1020 bytes, so those tables also switch to
-- ROW_FORMAT=DYNAMIC (needs an index prefix limit of at least 1020).
--
-- Collation: latin1 tables use utf8mb4_general_ci, not utf8mb4_swedish_ci.
-- On MariaDB 11, utf8mb4_swedish_ci equates U+00A0 (NBSP) with U+0020.
-- latin1_swedish_ci does not. sai.expediente.exp_numero has five pairs that
-- differ only by that byte, so the unique index cannot be built under swedish.
-- utf8mb4_general_ci keeps those pairs distinct. The other unique character
-- indexes in this copy stay unique under general_ci. tabgrales2 already
-- targets utf8mb4_general_ci. A table left at utf8mb4_swedish_ci by an
-- earlier run is converted again; that ALTER only changes collation.

SET NAMES utf8mb4;
SET @sai_old_fk = @@FOREIGN_KEY_CHECKS;
SET @sai_old_uq = @@UNIQUE_CHECKS;
SET @sai_old_safe = @@SQL_SAFE_UPDATES;
SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS = 0;
SET SQL_SAFE_UPDATES = 0;

USE `sai`;

DROP PROCEDURE IF EXISTS sai_exec_if_charset;
DROP PROCEDURE IF EXISTS sai_convert_table;
DROP PROCEDURE IF EXISTS sai_set_comment;
DELIMITER $$
CREATE PROCEDURE sai_exec_if_charset(
  IN p_schema VARCHAR(64),
  IN p_table VARCHAR(64),
  IN p_column VARCHAR(64),
  IN p_expected VARCHAR(32),
  IN p_sql TEXT
)
proc: BEGIN
  DECLARE v_cs VARCHAR(32) DEFAULT NULL;
  DECLARE v_msg VARCHAR(128);
  IF p_schema REGEXP '[^A-Za-z0-9_]' OR p_table REGEXP '[^A-Za-z0-9_]'
     OR p_column REGEXP '[^A-Za-z0-9_]' OR p_expected REGEXP '[^A-Za-z0-9_]' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'rejected identifier';
  END IF;
  SELECT CHARACTER_SET_NAME INTO v_cs
    FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = p_schema AND TABLE_NAME = p_table AND COLUMN_NAME = p_column
   LIMIT 1;
  IF v_cs IS NULL THEN
    SET v_msg = LEFT(CONCAT('missing column ', p_table, '.', p_column), 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_cs = p_expected THEN
    SET @sai_sql = p_sql;
    PREPARE sai_stmt FROM @sai_sql;
    EXECUTE sai_stmt;
    DEALLOCATE PREPARE sai_stmt;
    LEAVE proc;
  END IF;
  -- A finished conversion is utf8mb4: do not replace bytes again.
  -- A repair that still sees latin1 is skipped until CONVERT has run.
  IF (p_expected = 'latin1' AND v_cs = 'utf8mb4')
     OR (p_expected = 'utf8mb4' AND v_cs = 'latin1') THEN
    SELECT CONCAT('skip ', p_table, '.', p_column, ' charset ', v_cs, ' expected ', p_expected) AS sai_note;
    LEAVE proc;
  END IF;
  SET v_msg = LEFT(CONCAT(p_table, '.', p_column, ' is ', v_cs, ' not ', p_expected), 128);
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
END$$

CREATE PROCEDURE sai_convert_table(
  IN p_schema VARCHAR(64),
  IN p_table VARCHAR(64),
  IN p_family VARCHAR(16),
  IN p_collation VARCHAR(64),
  IN p_row_format VARCHAR(16)
)
proc: BEGIN
  DECLARE v_coll VARCHAR(64) DEFAULT NULL;
  DECLARE v_msg VARCHAR(128);
  IF p_schema REGEXP '[^A-Za-z0-9_]' OR p_table REGEXP '[^A-Za-z0-9_]'
     OR p_family REGEXP '[^A-Za-z0-9_]' OR p_collation REGEXP '[^A-Za-z0-9_]'
     OR p_row_format REGEXP '[^A-Za-z0-9_]' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'rejected identifier';
  END IF;
  IF p_collation NOT IN ('utf8mb4_swedish_ci', 'utf8mb4_general_ci') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'rejected collation';
  END IF;
  IF p_family NOT IN ('latin1', 'utf8') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'rejected source family';
  END IF;
  IF p_row_format NOT IN ('', 'DYNAMIC') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'rejected row format';
  END IF;
  SELECT TABLE_COLLATION INTO v_coll
    FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = p_schema AND TABLE_NAME = p_table
   LIMIT 1;
  IF v_coll IS NULL THEN
    SET v_msg = LEFT(CONCAT('missing table ', p_schema, '.', p_table), 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_coll = p_collation THEN
    SELECT CONCAT('skip convert, already ', p_collation, ': ', p_schema, '.', p_table) AS sai_note;
    LEAVE proc;
  END IF;
  IF v_coll LIKE 'utf8mb4%' THEN
    IF v_coll NOT IN ('utf8mb4_swedish_ci', 'utf8mb4_general_ci') THEN
      SET v_msg = LEFT(CONCAT(p_table, ' collation ', v_coll, ' is not a known utf8mb4 collation'), 128);
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
  ELSEIF p_family = 'latin1' AND LEFT(v_coll, 7) <> 'latin1_' THEN
    SET v_msg = LEFT(CONCAT(p_table, ' collation ', v_coll, ' is not latin1'), 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  ELSEIF p_family = 'utf8' AND LEFT(v_coll, 5) <> 'utf8_' AND LEFT(v_coll, 7) <> 'utf8mb3' THEN
    SET v_msg = LEFT(CONCAT(p_table, ' collation ', v_coll, ' is not utf8'), 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  SET @sai_sql = CONCAT('ALTER TABLE `', p_schema, '`.`', p_table, '` ');
  IF p_row_format <> '' THEN
    SET @sai_sql = CONCAT(@sai_sql, 'ROW_FORMAT=', p_row_format, ', ');
  END IF;
  SET @sai_sql = CONCAT(@sai_sql, 'CONVERT TO CHARACTER SET utf8mb4 COLLATE ', p_collation);
  PREPARE sai_stmt FROM @sai_sql;
  EXECUTE sai_stmt;
  DEALLOCATE PREPARE sai_stmt;
END$$

-- ALTER TABLE ... COMMENT rejects an expression. Build a quoted literal.
CREATE PROCEDURE sai_set_comment(
  IN p_schema VARCHAR(64),
  IN p_table VARCHAR(64),
  IN p_utf8 VARBINARY(2048)
)
BEGIN
  IF p_schema REGEXP '[^A-Za-z0-9_]' OR p_table REGEXP '[^A-Za-z0-9_]' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'rejected identifier';
  END IF;
  SET @sai_sql = CONCAT(
    'ALTER TABLE `', p_schema, '`.`', p_table, '` COMMENT = ',
    QUOTE(CONVERT(p_utf8 USING utf8mb4))
  );
  PREPARE sai_stmt FROM @sai_sql;
  EXECUTE sai_stmt;
  DEALLOCATE PREPARE sai_stmt;
END$$
DELIMITER ;

-- MariaDB returns 1832 if CONVERT changes a foreign-key column, even with
-- FOREIGN_KEY_CHECKS=0. Drop every key first and add it back at the end.
ALTER TABLE `sai`.`actividad_autodesarrollo` DROP FOREIGN KEY IF EXISTS `actividad_autodesarrollo_ibfk_1`;
ALTER TABLE `sai`.`actividad_autodesarrollo` DROP FOREIGN KEY IF EXISTS `actividad_autodesarrollo_ibfk_2`;
ALTER TABLE `sai`.`actividad_autodesarrollo_dictamen` DROP FOREIGN KEY IF EXISTS `actividad_autodesarrollo_dictamen_ibfk_3`;
ALTER TABLE `sai`.`actividad_autodesarrollo_dictamen` DROP FOREIGN KEY IF EXISTS `actividad_autodesarrollo_dictamen_ibfk_4`;
ALTER TABLE `sai`.`actividad_autodesarrollo_evento` DROP FOREIGN KEY IF EXISTS `actividad_autodesarrollo_evento_ibfk_12`;
ALTER TABLE `sai`.`actividad_autodesarrollo_evento` DROP FOREIGN KEY IF EXISTS `actividad_autodesarrollo_evento_ibfk_13`;
ALTER TABLE `sai`.`actividad_autodesarrollo_evento` DROP FOREIGN KEY IF EXISTS `actividad_autodesarrollo_evento_ibfk_14`;
ALTER TABLE `sai`.`actividad_autodesarrollo_evento` DROP FOREIGN KEY IF EXISTS `actividad_autodesarrollo_evento_ibfk_15`;
ALTER TABLE `sai`.`actividad_autodesarrollo_persona` DROP FOREIGN KEY IF EXISTS `actividad_autodesarrollo_persona_ibfk_32`;
ALTER TABLE `sai`.`actividad_autodesarrollo_persona` DROP FOREIGN KEY IF EXISTS `actividad_autodesarrollo_persona_ibfk_33`;
ALTER TABLE `sai`.`actividad_autodesarrollo_persona` DROP FOREIGN KEY IF EXISTS `actividad_autodesarrollo_persona_ibfk_34`;
ALTER TABLE `sai`.`actividad_autodesarrollo_persona` DROP FOREIGN KEY IF EXISTS `actividad_autodesarrollo_persona_ibfk_35`;
ALTER TABLE `sai`.`actividad_autodesarrollo_persona` DROP FOREIGN KEY IF EXISTS `actividad_autodesarrollo_persona_ibfk_37`;
ALTER TABLE `sai`.`actividad_autodesarrollo_persona` DROP FOREIGN KEY IF EXISTS `actividad_autodesarrollo_persona_ibfk_38`;
ALTER TABLE `sai`.`actividad_autodesarrollo_persona` DROP FOREIGN KEY IF EXISTS `actividad_autodesarrollo_persona_ibfk_40`;
ALTER TABLE `sai`.`actividad_autodesarrollo_persona` DROP FOREIGN KEY IF EXISTS `actividad_autodesarrollo_persona_ibfk_41`;
ALTER TABLE `sai`.`actividad_curso` DROP FOREIGN KEY IF EXISTS `actividad_curso_ibfk_1`;
ALTER TABLE `sai`.`actividad_curso` DROP FOREIGN KEY IF EXISTS `actividad_curso_ibfk_3`;
ALTER TABLE `sai`.`actividad_curso` DROP FOREIGN KEY IF EXISTS `actividad_curso_ibfk_4`;
ALTER TABLE `sai`.`actividad_curso_diseno_inap` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_inap_ibfk_1`;
ALTER TABLE `sai`.`actividad_curso_diseno_inap` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_inap_ibfk_2`;
ALTER TABLE `sai`.`actividad_curso_diseno_inap` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_inap_ibfk_3`;
ALTER TABLE `sai`.`actividad_curso_diseno_inap` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_inap_ibfk_4`;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_institucional_ibfk_10`;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_institucional_ibfk_11`;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_institucional_ibfk_12`;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_institucional_ibfk_13`;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_institucional_ibfk_9`;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional_persona` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_institucional_persona_ibfk_10`;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional_persona` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_institucional_persona_ibfk_11`;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional_persona` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_institucional_persona_ibfk_12`;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional_persona` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_institucional_persona_ibfk_6`;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional_persona` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_institucional_persona_ibfk_7`;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional_persona` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_institucional_persona_ibfk_8`;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional_persona` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_institucional_persona_ibfk_9`;
ALTER TABLE `sai`.`actividad_curso_diseno_jurisdiccional` DROP FOREIGN KEY IF EXISTS `actividad_curso_diseno_jurisdiccional_ibfk_1`;
ALTER TABLE `sai`.`actividad_curso_prestador_docente` DROP FOREIGN KEY IF EXISTS `actividad_curso_prestador_docente_ibfk_1`;
ALTER TABLE `sai`.`actividad_curso_prestador_docente` DROP FOREIGN KEY IF EXISTS `actividad_curso_prestador_docente_ibfk_2`;
ALTER TABLE `sai`.`actividad_eformal` DROP FOREIGN KEY IF EXISTS `actividad_eformal_ibfk_1`;
ALTER TABLE `sai`.`actividad_eformal` DROP FOREIGN KEY IF EXISTS `actividad_eformal_ibfk_2`;
ALTER TABLE `sai`.`actividad_eformal_persona` DROP FOREIGN KEY IF EXISTS `actividad_eformal_persona_ibfk_1`;
ALTER TABLE `sai`.`actividad_eformal_persona` DROP FOREIGN KEY IF EXISTS `actividad_eformal_persona_ibfk_2`;
ALTER TABLE `sai`.`actividad_externa` DROP FOREIGN KEY IF EXISTS `actividad_externa_ibfk_17`;
ALTER TABLE `sai`.`actividad_externa` DROP FOREIGN KEY IF EXISTS `actividad_externa_ibfk_18`;
ALTER TABLE `sai`.`actividad_externa` DROP FOREIGN KEY IF EXISTS `actividad_externa_ibfk_19`;
ALTER TABLE `sai`.`actividad_externa` DROP FOREIGN KEY IF EXISTS `actividad_externa_ibfk_20`;
ALTER TABLE `sai`.`actividad_externa` DROP FOREIGN KEY IF EXISTS `actividad_externa_ibfk_21`;
ALTER TABLE `sai`.`actividad_externa` DROP FOREIGN KEY IF EXISTS `actividad_externa_ibfk_22`;
ALTER TABLE `sai`.`actividad_externa_persona` DROP FOREIGN KEY IF EXISTS `actividad_externa_persona_ibfk_10`;
ALTER TABLE `sai`.`actividad_externa_persona` DROP FOREIGN KEY IF EXISTS `actividad_externa_persona_ibfk_2`;
ALTER TABLE `sai`.`actividad_externa_persona` DROP FOREIGN KEY IF EXISTS `actividad_externa_persona_ibfk_4`;
ALTER TABLE `sai`.`actividad_externa_persona` DROP FOREIGN KEY IF EXISTS `actividad_externa_persona_ibfk_6`;
ALTER TABLE `sai`.`actividad_externa_persona` DROP FOREIGN KEY IF EXISTS `actividad_externa_persona_ibfk_7`;
ALTER TABLE `sai`.`actividad_externa_persona` DROP FOREIGN KEY IF EXISTS `actividad_externa_persona_ibfk_9`;
ALTER TABLE `sai`.`actividad_formato_actividad` DROP FOREIGN KEY IF EXISTS `actividad_formato_actividad_ibfk_1`;
ALTER TABLE `sai`.`actividad_formato_actividad` DROP FOREIGN KEY IF EXISTS `actividad_formato_actividad_ibfk_2`;
ALTER TABLE `sai`.`actividad_programacion` DROP FOREIGN KEY IF EXISTS `actividad_programacion_ibfk_1`;
ALTER TABLE `sai`.`actividad_programacion` DROP FOREIGN KEY IF EXISTS `actividad_programacion_ibfk_2`;
ALTER TABLE `sai`.`actividad_programacion` DROP FOREIGN KEY IF EXISTS `actividad_programacion_ibfk_3`;
ALTER TABLE `sai`.`agente` DROP FOREIGN KEY IF EXISTS `agente_ibfk_1`;
ALTER TABLE `sai`.`agente` DROP FOREIGN KEY IF EXISTS `agente_ibfk_3`;
ALTER TABLE `sai`.`agente` DROP FOREIGN KEY IF EXISTS `agente_ibfk_5`;
ALTER TABLE `sai`.`agente` DROP FOREIGN KEY IF EXISTS `agente_ibfk_6`;
ALTER TABLE `sai`.`agente` DROP FOREIGN KEY IF EXISTS `agente_ibfk_7`;
ALTER TABLE `sai`.`agente_temp` DROP FOREIGN KEY IF EXISTS `agente_temp_ibfk_1`;
ALTER TABLE `sai`.`agente_temp` DROP FOREIGN KEY IF EXISTS `agente_temp_ibfk_2`;
ALTER TABLE `sai`.`agente_temp` DROP FOREIGN KEY IF EXISTS `agente_temp_ibfk_3`;
ALTER TABLE `sai`.`agente_temp` DROP FOREIGN KEY IF EXISTS `agente_temp_ibfk_4`;
ALTER TABLE `sai`.`agente_temp` DROP FOREIGN KEY IF EXISTS `agente_temp_ibfk_5`;
ALTER TABLE `sai`.`agente_temp` DROP FOREIGN KEY IF EXISTS `agente_temp_ibfk_6`;
ALTER TABLE `sai`.`comision` DROP FOREIGN KEY IF EXISTS `comision_ibfk_10`;
ALTER TABLE `sai`.`comision` DROP FOREIGN KEY IF EXISTS `comision_ibfk_11`;
ALTER TABLE `sai`.`comision` DROP FOREIGN KEY IF EXISTS `comision_ibfk_7`;
ALTER TABLE `sai`.`comision` DROP FOREIGN KEY IF EXISTS `comision_ibfk_8`;
ALTER TABLE `sai`.`comision` DROP FOREIGN KEY IF EXISTS `comision_ibfk_9`;
ALTER TABLE `sai`.`comision_fecha` DROP FOREIGN KEY IF EXISTS `comision_fecha_ibfk_1`;
ALTER TABLE `sai`.`comision_persona` DROP FOREIGN KEY IF EXISTS `comision_persona_ibfk_1`;
ALTER TABLE `sai`.`comision_persona` DROP FOREIGN KEY IF EXISTS `comision_persona_ibfk_2`;
ALTER TABLE `sai`.`comision_persona` DROP FOREIGN KEY IF EXISTS `comision_persona_ibfk_4`;
ALTER TABLE `sai`.`comision_persona` DROP FOREIGN KEY IF EXISTS `comision_persona_ibfk_5`;
ALTER TABLE `sai`.`comision_persona` DROP FOREIGN KEY IF EXISTS `comision_persona_ibfk_7`;
ALTER TABLE `sai`.`comision_persona` DROP FOREIGN KEY IF EXISTS `comision_persona_ibfk_8`;
ALTER TABLE `sai`.`comision_persona` DROP FOREIGN KEY IF EXISTS `comision_persona_ibfk_9`;
ALTER TABLE `sai`.`comision_persona_candidato` DROP FOREIGN KEY IF EXISTS `comision_persona_candidato_ibfk_10`;
ALTER TABLE `sai`.`comision_persona_candidato` DROP FOREIGN KEY IF EXISTS `comision_persona_candidato_ibfk_11`;
ALTER TABLE `sai`.`comision_persona_candidato` DROP FOREIGN KEY IF EXISTS `comision_persona_candidato_ibfk_12`;
ALTER TABLE `sai`.`comision_persona_candidato` DROP FOREIGN KEY IF EXISTS `comision_persona_candidato_ibfk_13`;
ALTER TABLE `sai`.`comision_persona_candidato` DROP FOREIGN KEY IF EXISTS `comision_persona_candidato_ibfk_8`;
ALTER TABLE `sai`.`comision_persona_candidato` DROP FOREIGN KEY IF EXISTS `comision_persona_candidato_ibfk_9`;
ALTER TABLE `sai`.`comision_prestador_docente` DROP FOREIGN KEY IF EXISTS `comision_prestador_docente_ibfk_1`;
ALTER TABLE `sai`.`comision_prestador_docente` DROP FOREIGN KEY IF EXISTS `comision_prestador_docente_ibfk_2`;
ALTER TABLE `sai`.`constantes_grales` DROP FOREIGN KEY IF EXISTS `constantes_grales_ibfk_1`;
ALTER TABLE `sai`.`datos_documentos` DROP FOREIGN KEY IF EXISTS `dto_jurisdinap`;
ALTER TABLE `sai`.`dictamen` DROP FOREIGN KEY IF EXISTS `dictamen_ibfk_1`;
ALTER TABLE `sai`.`dictamen` DROP FOREIGN KEY IF EXISTS `dictamen_ibfk_2`;
ALTER TABLE `sai`.`dictamen` DROP FOREIGN KEY IF EXISTS `dictamen_ibfk_3`;
ALTER TABLE `sai`.`dictamen` DROP FOREIGN KEY IF EXISTS `dictamen_ibfk_4`;
ALTER TABLE `sai`.`escalafones_agrup_niveles_grados` DROP FOREIGN KEY IF EXISTS `escalafones_agrup_niveles_grados_ibfk_1`;
ALTER TABLE `sai`.`escalafones_agrup_niveles_grados` DROP FOREIGN KEY IF EXISTS `escalafones_agrup_niveles_grados_ibfk_2`;
ALTER TABLE `sai`.`escalafones_agrup_niveles_grados` DROP FOREIGN KEY IF EXISTS `escalafones_agrup_niveles_grados_ibfk_3`;
ALTER TABLE `sai`.`escalafones_agrup_niveles_grados` DROP FOREIGN KEY IF EXISTS `escalafones_agrup_niveles_grados_ibfk_4`;
ALTER TABLE `sai`.`expediente` DROP FOREIGN KEY IF EXISTS `expediente_ibfk_1`;
ALTER TABLE `sai`.`gruposmod_modulos` DROP FOREIGN KEY IF EXISTS `gruposmod_modulos_ibfk_1`;
ALTER TABLE `sai`.`gruposmod_modulos` DROP FOREIGN KEY IF EXISTS `gruposmod_modulos_ibfk_2`;
ALTER TABLE `sai`.`logusuarios` DROP FOREIGN KEY IF EXISTS `logusuarios_ibfk_1`;
ALTER TABLE `sai`.`modulos` DROP FOREIGN KEY IF EXISTS `modulos_ibfk_1`;
ALTER TABLE `sai`.`modulos_archivos` DROP FOREIGN KEY IF EXISTS `modulos_archivos_ibfk_1`;
ALTER TABLE `sai`.`modulos_archivos` DROP FOREIGN KEY IF EXISTS `modulos_archivos_ibfk_2`;
ALTER TABLE `sai`.`poc` DROP FOREIGN KEY IF EXISTS `poc_ibfk_1`;
ALTER TABLE `sai`.`poc_actividad` DROP FOREIGN KEY IF EXISTS `poc_actividad_ibfk_1`;
ALTER TABLE `sai`.`poc_actividad` DROP FOREIGN KEY IF EXISTS `poc_actividad_ibfk_2`;
ALTER TABLE `sai`.`poc_actividad_actividad` DROP FOREIGN KEY IF EXISTS `poc_actividad_actividad_ibfk_3`;
ALTER TABLE `sai`.`poc_actividad_actividad` DROP FOREIGN KEY IF EXISTS `poc_actividad_actividad_ibfk_4`;
ALTER TABLE `sai`.`poc_actividad_poc_objetivo` DROP FOREIGN KEY IF EXISTS `poc_actividad_poc_objetivo_ibfk_1`;
ALTER TABLE `sai`.`poc_actividad_poc_objetivo` DROP FOREIGN KEY IF EXISTS `poc_actividad_poc_objetivo_ibfk_2`;
ALTER TABLE `sai`.`poc_area` DROP FOREIGN KEY IF EXISTS `poc_area_ibfk_1`;
ALTER TABLE `sai`.`poc_objetivo` DROP FOREIGN KEY IF EXISTS `poc_objetivo_ibfk_1`;
ALTER TABLE `sai`.`poc_poc_objetivo_poc_area` DROP FOREIGN KEY IF EXISTS `poc_poc_objetivo_poc_area_ibfk_1`;
ALTER TABLE `sai`.`poc_poc_objetivo_poc_area` DROP FOREIGN KEY IF EXISTS `poc_poc_objetivo_poc_area_ibfk_2`;
ALTER TABLE `sai`.`poc_poc_objetivo_poc_area` DROP FOREIGN KEY IF EXISTS `poc_poc_objetivo_poc_area_ibfk_3`;
ALTER TABLE `sai`.`ponderador_tipo_participacion_escalafon_nivel` DROP FOREIGN KEY IF EXISTS `FK_ponderador_tipo_participacion_escalafon_nivel`;
ALTER TABLE `sai`.`ponderador_tipo_participacion_escalafon_nivel` DROP FOREIGN KEY IF EXISTS `ponderador_tipo_participacion_escalafon_nivel_ibfk_1`;
ALTER TABLE `sai`.`ponderador_tipo_participacion_escalafon_nivel` DROP FOREIGN KEY IF EXISTS `ponderador_tipo_participacion_escalafon_nivel_ibfk_2`;
ALTER TABLE `sai`.`ponderador_tipo_participacion_escalafon_nivel` DROP FOREIGN KEY IF EXISTS `ponderador_tipo_participacion_escalafon_nivel_ibfk_3`;
ALTER TABLE `sai`.`ponderador_tipo_ponderador` DROP FOREIGN KEY IF EXISTS `ponderador_tipo_ponderador_ibfk_1`;
ALTER TABLE `sai`.`prestador_docente` DROP FOREIGN KEY IF EXISTS `prestador_docente_ibfk_21`;
ALTER TABLE `sai`.`prestador_docente` DROP FOREIGN KEY IF EXISTS `prestador_docente_ibfk_23`;
ALTER TABLE `sai`.`prestador_docente` DROP FOREIGN KEY IF EXISTS `prestador_docente_ibfk_24`;
ALTER TABLE `sai`.`prestador_docente` DROP FOREIGN KEY IF EXISTS `prestador_docente_ibfk_25`;
ALTER TABLE `sai`.`prestador_docente` DROP FOREIGN KEY IF EXISTS `prestador_docente_ibfk_26`;
ALTER TABLE `sai`.`prestador_docente_area_especifica` DROP FOREIGN KEY IF EXISTS `prestador_docente_area_especifica_ibfk_17`;
ALTER TABLE `sai`.`prestador_docente_area_especifica` DROP FOREIGN KEY IF EXISTS `prestador_docente_area_especifica_ibfk_18`;
ALTER TABLE `sai`.`prestador_docente_tipo_postulacion` DROP FOREIGN KEY IF EXISTS `prestador_docente_tipo_postulacion_ibfk_1`;
ALTER TABLE `sai`.`prestador_docente_tipo_postulacion` DROP FOREIGN KEY IF EXISTS `prestador_docente_tipo_postulacion_ibfk_2`;
ALTER TABLE `sai`.`prestador_institucional` DROP FOREIGN KEY IF EXISTS `prestador_institucional_ibfk_10`;
ALTER TABLE `sai`.`roles_abm_roles` DROP FOREIGN KEY IF EXISTS `roles_abm_roles_ibfk_1`;
ALTER TABLE `sai`.`roles_abm_roles` DROP FOREIGN KEY IF EXISTS `roles_abm_roles_ibfk_2`;
ALTER TABLE `sai`.`roles_modulos` DROP FOREIGN KEY IF EXISTS `roles_modulos_ibfk_1`;
ALTER TABLE `sai`.`roles_modulos` DROP FOREIGN KEY IF EXISTS `roles_modulos_ibfk_2`;
ALTER TABLE `sai`.`roles_tipo_actividad` DROP FOREIGN KEY IF EXISTS `roles_tipo_actividad_ibfk_1`;
ALTER TABLE `sai`.`roles_tipo_actividad` DROP FOREIGN KEY IF EXISTS `roles_tipo_actividad_ibfk_2`;
ALTER TABLE `sai`.`tipoact_agrega_tipoact` DROP FOREIGN KEY IF EXISTS `tipoact_agrega_tipoact_ibfk_3`;
ALTER TABLE `sai`.`tipoact_agrega_tipoact` DROP FOREIGN KEY IF EXISTS `tipoact_agrega_tipoact_ibfk_4`;
ALTER TABLE `sai`.`tipo_actividad` DROP FOREIGN KEY IF EXISTS `tipo_actividad_ibfk_1`;
ALTER TABLE `sai`.`tipo_participacion` DROP FOREIGN KEY IF EXISTS `tipo_participacion_ibfk_1`;
ALTER TABLE `sai`.`usuarios_enlace_jurisdiccion_inap` DROP FOREIGN KEY IF EXISTS `usuarios_enlace_jurisdiccion_inap_ibfk_1`;
ALTER TABLE `sai`.`usuarios_roles_jurisdiccion_inap` DROP FOREIGN KEY IF EXISTS `usuarios_roles_jurisdiccion_inap_ibfk_1`;
ALTER TABLE `sai`.`usuarios_roles_jurisdiccion_inap` DROP FOREIGN KEY IF EXISTS `usuarios_roles_jurisdiccion_inap_ibfk_2`;
ALTER TABLE `sai`.`usuarios_roles_jurisdiccion_inap` DROP FOREIGN KEY IF EXISTS `usuarios_roles_jurisdiccion_inap_ibfk_3`;
ALTER TABLE `sai`.`usuarios_roles_jurisdiccion_inap_modulos` DROP FOREIGN KEY IF EXISTS `usuarios_roles_jurisdiccion_inap_modulos_ibfk_1`;
ALTER TABLE `sai`.`usuarios_roles_jurisdiccion_inap_modulos` DROP FOREIGN KEY IF EXISTS `usuarios_roles_jurisdiccion_inap_modulos_ibfk_2`;
ALTER TABLE `sai`.`usuario_universidad` DROP FOREIGN KEY IF EXISTS `usuario_universidad_ibfk_1`;
ALTER TABLE `sai`.`usuario_universidad` DROP FOREIGN KEY IF EXISTS `usuario_universidad_ibfk_2`;
ALTER TABLE `tabgrales2`.`categorias_00001` DROP FOREIGN KEY IF EXISTS `categorias_00001_ibfk_3`;
ALTER TABLE `tabgrales2`.`categorias_00001` DROP FOREIGN KEY IF EXISTS `categorias_00001_ibfk_4`;
ALTER TABLE `tabgrales2`.`categorias_00001` DROP FOREIGN KEY IF EXISTS `categorias_00001_ibfk_5`;
ALTER TABLE `tabgrales2`.`constantes_grales` DROP FOREIGN KEY IF EXISTS `constantes_grales_ibfk_1`;
ALTER TABLE `tabgrales2`.`gruposmod_modulos` DROP FOREIGN KEY IF EXISTS `gruposmod_modulos_ibfk_1`;
ALTER TABLE `tabgrales2`.`gruposmod_modulos` DROP FOREIGN KEY IF EXISTS `gruposmod_modulos_ibfk_2`;
ALTER TABLE `tabgrales2`.`jurisdicciones_00001` DROP FOREIGN KEY IF EXISTS `FK_jurisdicciones_00001`;
ALTER TABLE `tabgrales2`.`jurisdicciones_00001` DROP FOREIGN KEY IF EXISTS `jurisdicciones_00001_ibfk_1`;
ALTER TABLE `tabgrales2`.`jurisdicciones_00001` DROP FOREIGN KEY IF EXISTS `jurisdicciones_00001_ibfk_7`;
ALTER TABLE `tabgrales2`.`jurisdicciones_00001` DROP FOREIGN KEY IF EXISTS `jurisdicciones_00001_ibfk_8`;
ALTER TABLE `tabgrales2`.`logusuarios` DROP FOREIGN KEY IF EXISTS `logusuarios_ibfk_1`;
ALTER TABLE `tabgrales2`.`log_modificaciones_00001` DROP FOREIGN KEY IF EXISTS `log_modificaciones_00001_ibfk_1`;
ALTER TABLE `tabgrales2`.`log_modificaciones_00001` DROP FOREIGN KEY IF EXISTS `log_modificaciones_00001_ibfk_2`;
ALTER TABLE `tabgrales2`.`modulos` DROP FOREIGN KEY IF EXISTS `modulos_ibfk_1`;
ALTER TABLE `tabgrales2`.`modulos_archivos` DROP FOREIGN KEY IF EXISTS `modulos_archivos_ibfk_1`;
ALTER TABLE `tabgrales2`.`modulos_archivos` DROP FOREIGN KEY IF EXISTS `modulos_archivos_ibfk_2`;
ALTER TABLE `tabgrales2`.`normas_juridicas_00001` DROP FOREIGN KEY IF EXISTS `normas_juridicas_00001_ibfk_1`;
ALTER TABLE `tabgrales2`.`normas_juridicas_00001` DROP FOREIGN KEY IF EXISTS `normas_juridicas_00001_ibfk_2`;
ALTER TABLE `tabgrales2`.`rel_cat_cat_00001` DROP FOREIGN KEY IF EXISTS `rel_cat_cat_00001_ibfk_1`;
ALTER TABLE `tabgrales2`.`rel_cat_cat_00001` DROP FOREIGN KEY IF EXISTS `rel_cat_cat_00001_ibfk_2`;
ALTER TABLE `tabgrales2`.`rel_torg_torg_00001` DROP FOREIGN KEY IF EXISTS `rel_torg_torg_00001_ibfk_1`;
ALTER TABLE `tabgrales2`.`rel_torg_torg_00001` DROP FOREIGN KEY IF EXISTS `rel_torg_torg_00001_ibfk_2`;
ALTER TABLE `tabgrales2`.`roles_abm_roles` DROP FOREIGN KEY IF EXISTS `roles_abm_roles_ibfk_1`;
ALTER TABLE `tabgrales2`.`roles_abm_roles` DROP FOREIGN KEY IF EXISTS `roles_abm_roles_ibfk_2`;
ALTER TABLE `tabgrales2`.`roles_modulos` DROP FOREIGN KEY IF EXISTS `roles_modulos_ibfk_1`;
ALTER TABLE `tabgrales2`.`roles_modulos` DROP FOREIGN KEY IF EXISTS `roles_modulos_ibfk_2`;
ALTER TABLE `tabgrales2`.`tiposorganismos_00001` DROP FOREIGN KEY IF EXISTS `tiposorganismos_00001_ibfk_1`;
ALTER TABLE `tabgrales2`.`tiposorganismos_00001` DROP FOREIGN KEY IF EXISTS `tiposorganismos_00001_ibfk_2`;
ALTER TABLE `tabgrales2`.`usuarios_roles` DROP FOREIGN KEY IF EXISTS `usuarios_roles_ibfk_1`;
ALTER TABLE `tabgrales2`.`usuarios_roles` DROP FOREIGN KEY IF EXISTS `usuarios_roles_ibfk_2`;

-- sai: latin1. Repair the five columns, then convert each table.
-- Collation is utf8mb4_general_ci. utf8mb4_swedish_ci cannot keep expediente.exp_numero unique.
-- actividad: 3 character column(s): act_codinap, act_nombre, act_obs
CALL sai_convert_table('sai', 'actividad', 'latin1', 'utf8mb4_general_ci', '');

-- actividad_autodesarrollo: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'actividad_autodesarrollo', 'latin1', 'utf8mb4_general_ci', '');

-- actividad_autodesarrollo_dictamen: 1 character column(s): actautodic_obs
CALL sai_convert_table('sai', 'actividad_autodesarrollo_dictamen', 'latin1', 'utf8mb4_general_ci', '');

-- actividad_autodesarrollo_evento: 4 character column(s): actautoeven_duraciondetalle, prov_codigo, actautoeven_direccion, actautoeven_obs
CALL sai_convert_table('sai', 'actividad_autodesarrollo_evento', 'latin1', 'utf8mb4_general_ci', '');

-- actividad_autodesarrollo_persona: 2 character column(s): actauto_obs, provinciacod_revista
CALL sai_convert_table('sai', 'actividad_autodesarrollo_persona', 'latin1', 'utf8mb4_general_ci', '');

-- actividad_curso: 1 character column(s): actcur_obs
CALL sai_convert_table('sai', 'actividad_curso', 'latin1', 'utf8mb4_general_ci', '');

-- actividad_curso_diseno_inap: 20 character column(s): actdisinap_fundamentacion, actdisinap_contribucion, actdisinap_perfil, actdisinap_objetivos, actdisinap_contenido, actdisinap_modaldesc, actdisinap_eval, actdisinap_evalinstru, actdisinap_requiaprobacion, actdisinap_duraciondetalle, actdisinap_lugar, actdisinap_metodologia, actdisinap_bibliografia, actdisinap_perfil_instructor, actdisinap_planrecursos, actdisinap_plancontenidos, actdisinap_planestrategias, actdisinap_origen, actdisinap_unico, actdisinap_beca
-- Repair stuffed UTF-8 in `sai`.`actividad_curso_diseno_inap`.`actdisinap_bibliografia` while it is latin1 (0xC2BA->0xBA x4).
CALL sai_exec_if_charset('sai', 'actividad_curso_diseno_inap', 'actdisinap_bibliografia', 'latin1', 'UPDATE `sai`.`actividad_curso_diseno_inap` SET `actdisinap_bibliografia` = CONVERT(REPLACE(CONVERT(`actdisinap_bibliografia` USING binary), 0xC2BA, 0xBA) USING latin1) WHERE INSTR(CONVERT(`actdisinap_bibliografia` USING binary), 0xC2BA) > 0');

CALL sai_convert_table('sai', 'actividad_curso_diseno_inap', 'latin1', 'utf8mb4_general_ci', '');

-- actividad_curso_diseno_institucional: 12 character column(s): actdisinst_fundamentacion, actdisinst_perfil, actdisinst_objetivos, actdisinst_contenido, actdisinst_eval, actdisinst_requiaprobacion, actdisinst_duraciondetalle, prov_codigo, actdisinst_direccion, actdisinst_metodologia, actdisinst_bibliografia, actdisinst_perfil_instructor
CALL sai_convert_table('sai', 'actividad_curso_diseno_institucional', 'latin1', 'utf8mb4_general_ci', '');

-- actividad_curso_diseno_institucional_persona: 2 character column(s): actextpers_obs, provinciacod_revista
CALL sai_convert_table('sai', 'actividad_curso_diseno_institucional_persona', 'latin1', 'utf8mb4_general_ci', '');

-- actividad_curso_diseno_jurisdiccional: 21 character column(s): actdisjurisd_fundamentacion, actdisjurisd_contribucion, actdisjurisd_perfil, actdisjurisd_objetivos, actdisjurisd_contenido, actdisjurisd_modaldesc, actdisjurisd_eval, actdisjurisd_evalinstru, actdisjurisd_requiaprobacion, actdisjurisd_duraciondetalle, actdisjurisd_cronogramatentativo, actdisjurisd_lugar, actdisjurisd_hist_evaluacion, actdisjurisd_metodologia, actdisjurisd_bibliografia, actdisjurisd_perfil_instructor, actdisjurisd_planrecursos, actdisjurisd_plancontenidos, actdisjurisd_planestrategias, actdisjurisd_origen, Copia_de_actdisjurisd_duraciondetalle
-- Repair stuffed UTF-8 in `sai`.`actividad_curso_diseno_jurisdiccional`.`actdisjurisd_bibliografia` while it is latin1 (0xC2BA->0xBA x1).
CALL sai_exec_if_charset('sai', 'actividad_curso_diseno_jurisdiccional', 'actdisjurisd_bibliografia', 'latin1', 'UPDATE `sai`.`actividad_curso_diseno_jurisdiccional` SET `actdisjurisd_bibliografia` = CONVERT(REPLACE(CONVERT(`actdisjurisd_bibliografia` USING binary), 0xC2BA, 0xBA) USING latin1) WHERE INSTR(CONVERT(`actdisjurisd_bibliografia` USING binary), 0xC2BA) > 0');

CALL sai_convert_table('sai', 'actividad_curso_diseno_jurisdiccional', 'latin1', 'utf8mb4_general_ci', '');

-- actividad_curso_prestador_docente: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'actividad_curso_prestador_docente', 'latin1', 'utf8mb4_general_ci', '');

-- actividad_eformal: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'actividad_eformal', 'latin1', 'utf8mb4_general_ci', '');

-- actividad_eformal_persona: 5 character column(s): actformpers_titulo, actformpers_institucion, actformpers_materias, actformpers_obs, provinciacod_revista
CALL sai_convert_table('sai', 'actividad_eformal_persona', 'latin1', 'utf8mb4_general_ci', '');

-- actividad_externa: 4 character column(s): actext_duraciondetalle, prov_codigo, actext_direccion, actext_obs
CALL sai_convert_table('sai', 'actividad_externa', 'latin1', 'utf8mb4_general_ci', '');

-- actividad_externa_persona: 2 character column(s): actextpers_obs, provinciacod_revista
CALL sai_convert_table('sai', 'actividad_externa_persona', 'latin1', 'utf8mb4_general_ci', '');

-- actividad_formato_actividad: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'actividad_formato_actividad', 'latin1', 'utf8mb4_general_ci', '');

-- actividad_programacion: 1 character column(s): actprog_obs
CALL sai_convert_table('sai', 'actividad_programacion', 'latin1', 'utf8mb4_general_ci', '');

-- agente: 1 character column(s): provinciacod_revista
CALL sai_convert_table('sai', 'agente', 'latin1', 'utf8mb4_general_ci', '');

-- agente_funcion: 1 character column(s): agfunc_descripcion
CALL sai_convert_table('sai', 'agente_funcion', 'latin1', 'utf8mb4_general_ci', '');

-- agente_temp: 1 character column(s): provinciacod_revista
CALL sai_convert_table('sai', 'agente_temp', 'latin1', 'utf8mb4_general_ci', '');

-- agrupamientos: 3 character column(s): agrupnom, agrupdesc, agrupcodreper
CALL sai_convert_table('sai', 'agrupamientos', 'latin1', 'utf8mb4_general_ci', '');

-- archivos: 1 character column(s): archivonom
CALL sai_convert_table('sai', 'archivos', 'latin1', 'utf8mb4_general_ci', '');

-- area_contextual: 1 character column(s): areacon_descripcion
CALL sai_convert_table('sai', 'area_contextual', 'latin1', 'utf8mb4_general_ci', '');

-- area_curso_inap: 2 character column(s): areacur_descripcion, areacur_prefijo
CALL sai_convert_table('sai', 'area_curso_inap', 'latin1', 'utf8mb4_general_ci', '');

-- area_especifica: 1 character column(s): areaesp_descripcion
CALL sai_convert_table('sai', 'area_especifica', 'latin1', 'utf8mb4_general_ci', '');

-- area_general: 1 character column(s): areagen_descripcion
CALL sai_convert_table('sai', 'area_general', 'latin1', 'utf8mb4_general_ci', '');

-- carrera: 1 character column(s): carr_descripcion
CALL sai_convert_table('sai', 'carrera', 'latin1', 'utf8mb4_general_ci', '');

-- comision: 5 character column(s): comi_codinap, prov_codigo, comi_domicilio, comi_detalle, comi_web
CALL sai_convert_table('sai', 'comision', 'latin1', 'utf8mb4_general_ci', '');

-- comision_fecha: 2 character column(s): comifec_hora_inicio, comifec_hora_fin
CALL sai_convert_table('sai', 'comision_fecha', 'latin1', 'utf8mb4_general_ci', '');

-- comision_persona: 1 character column(s): provinciacod_revista
CALL sai_convert_table('sai', 'comision_persona', 'latin1', 'utf8mb4_general_ci', '');

-- comision_persona_candidato: 8 character column(s): pers_cuilt, pers_nombre, pers_apellido, pers_sexo, pers_email, provinciacod_revista, tareas, cambio_datos
CALL sai_convert_table('sai', 'comision_persona_candidato', 'latin1', 'utf8mb4_general_ci', '');

-- comision_prestador_docente: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'comision_prestador_docente', 'latin1', 'utf8mb4_general_ci', '');

-- constantes_grales: 5 character column(s): sistemanom, constantetipo, constantecod, constantenom, constantedesc
CALL sai_convert_table('sai', 'constantes_grales', 'latin1', 'utf8mb4_general_ci', '');

-- constantes_grales_OLD: 5 character column(s): sistemanom, constantetipo, constantecod, constantenom, constantedesc
CALL sai_convert_table('sai', 'constantes_grales_OLD', 'latin1', 'utf8mb4_general_ci', '');

-- datos_documentos: 6 character column(s): dto_linea_encabezado, dto_sello_linea1, dto_sello_linea2, dto_sello_linea3, dto_default, dto_linea_nota
CALL sai_convert_table('sai', 'datos_documentos', 'latin1', 'utf8mb4_general_ci', '');

-- dictamen: 4 character column(s): dic_pertinencia, dic_hist_evaluacion, dic_observaciones, dic_visado_obs
CALL sai_convert_table('sai', 'dictamen', 'latin1', 'utf8mb4_general_ci', '');

-- disposicion: 2 character column(s): dis_numero, dis_obs
CALL sai_convert_table('sai', 'disposicion', 'latin1', 'utf8mb4_general_ci', '');

-- escalafones: 2 character column(s): escalafnom, escalafdesc
CALL sai_convert_table('sai', 'escalafones', 'latin1', 'utf8mb4_general_ci', '');

-- escalafones_agrup_niveles_grados: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'escalafones_agrup_niveles_grados', 'latin1', 'utf8mb4_general_ci', '');

-- escalafones_grados: 2 character column(s): escalafgradonom, escalafgradodesc
CALL sai_convert_table('sai', 'escalafones_grados', 'latin1', 'utf8mb4_general_ci', '');

-- escalafones_niveles: 2 character column(s): escalafnivnom, escalafnivdesc
CALL sai_convert_table('sai', 'escalafones_niveles', 'latin1', 'utf8mb4_general_ci', '');

-- escalafones_tramos: 2 character column(s): escalaftramonom, escalaftramodesc
CALL sai_convert_table('sai', 'escalafones_tramos', 'latin1', 'utf8mb4_general_ci', '');

-- evaluacion: 3 character column(s): eval_nom, eval_descripcion, eval_certifica
CALL sai_convert_table('sai', 'evaluacion', 'latin1', 'utf8mb4_general_ci', '');

-- expediente: 2 character column(s): exp_numero, exp_obs
CALL sai_convert_table('sai', 'expediente', 'latin1', 'utf8mb4_general_ci', '');

-- formato_actividad: 2 character column(s): formact_nom, formact_descripcion
CALL sai_convert_table('sai', 'formato_actividad', 'latin1', 'utf8mb4_general_ci', '');

-- gruposmod: 1 character column(s): grupomodtextomenu
CALL sai_convert_table('sai', 'gruposmod', 'latin1', 'utf8mb4_general_ci', '');

-- gruposmod_modulos: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'gruposmod_modulos', 'latin1', 'utf8mb4_general_ci', '');

-- jurisdiccion_inap: 3 character column(s): jurisdnom, jurisdinap_obs_migra, jurisd_prefijo_comision
CALL sai_convert_table('sai', 'jurisdiccion_inap', 'latin1', 'utf8mb4_general_ci', '');

-- jurisdiccion_inap2: 3 character column(s): jurisdnom, jurisdinap_obs_migra, jurisd_prefijo_comision
CALL sai_convert_table('sai', 'jurisdiccion_inap2', 'latin1', 'utf8mb4_general_ci', '');

-- localidades: 4 character column(s): provinciacod, partidocod, localidadcod, localidadnom
CALL sai_convert_table('sai', 'localidades', 'latin1', 'utf8mb4_general_ci', '');

-- log_mensajes: 1 character column(s): descripcion
CALL sai_convert_table('sai', 'log_mensajes', 'latin1', 'utf8mb4_general_ci', '');

-- logusuarios: 4 character column(s): acciondesc, numeroip, archivonom, usuariocod
-- Repair stuffed UTF-8 in `sai`.`logusuarios`.`acciondesc` while it is latin1 (0xC2BF->0xBF x3).
CALL sai_exec_if_charset('sai', 'logusuarios', 'acciondesc', 'latin1', 'UPDATE `sai`.`logusuarios` SET `acciondesc` = CONVERT(REPLACE(CONVERT(`acciondesc` USING binary), 0xC2BF, 0xBF) USING latin1) WHERE INSTR(CONVERT(`acciondesc` USING binary), 0xC2BF) > 0');

CALL sai_convert_table('sai', 'logusuarios', 'latin1', 'utf8mb4_general_ci', '');
-- Restore UTF-8 that does not fit in latin1 in `sai`.`logusuarios`.`acciondesc` (0xEFB9A5 x6).
CALL sai_exec_if_charset('sai', 'logusuarios', 'acciondesc', 'utf8mb4', 'UPDATE `sai`.`logusuarios` SET `acciondesc` = REPLACE(`acciondesc`, CONVERT(0xEFB9A5 USING latin1), CONVERT(0xEFB9A5 USING utf8mb4)) WHERE INSTR(`acciondesc`, CONVERT(0xEFB9A5 USING latin1)) > 0');


-- mensajes_internos: 7 character column(s): sis_nombre, msg_ip_origen, msg_asunto, msg_mensaje, msg_archivo_ejec, msg_funcion, msg_variables
-- Repair stuffed UTF-8 in `sai`.`mensajes_internos`.`msg_mensaje` while it is latin1 (0xC3B3->0xF3 x4898, 0xC3A1->0xE1 x280, 0xC2BF->0xBF x12, 0xC3AD->0xED x6).
CALL sai_exec_if_charset('sai', 'mensajes_internos', 'msg_mensaje', 'latin1', 'UPDATE `sai`.`mensajes_internos` SET `msg_mensaje` = CONVERT(REPLACE(REPLACE(REPLACE(REPLACE(CONVERT(`msg_mensaje` USING binary), 0xC3B3, 0xF3), 0xC3A1, 0xE1), 0xC2BF, 0xBF), 0xC3AD, 0xED) USING latin1) WHERE INSTR(CONVERT(`msg_mensaje` USING binary), 0xC3B3) > 0 OR INSTR(CONVERT(`msg_mensaje` USING binary), 0xC3A1) > 0 OR INSTR(CONVERT(`msg_mensaje` USING binary), 0xC2BF) > 0 OR INSTR(CONVERT(`msg_mensaje` USING binary), 0xC3AD) > 0');

-- Repair stuffed UTF-8 in `sai`.`mensajes_internos`.`msg_variables` while it is latin1 (0xC3B3->0xF3 x36, 0xC3B1->0xF1 x12, 0xC3A1->0xE1 x8, 0xC3AD->0xED x8, 0xC2BF->0xBF x6, 0xC3AC->0xEC x2, 0xC3A9->0xE9 x2).
CALL sai_exec_if_charset('sai', 'mensajes_internos', 'msg_variables', 'latin1', 'UPDATE `sai`.`mensajes_internos` SET `msg_variables` = CONVERT(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CONVERT(`msg_variables` USING binary), 0xC3B3, 0xF3), 0xC3B1, 0xF1), 0xC3A1, 0xE1), 0xC3AD, 0xED), 0xC2BF, 0xBF), 0xC3AC, 0xEC), 0xC3A9, 0xE9) USING latin1) WHERE INSTR(CONVERT(`msg_variables` USING binary), 0xC3B3) > 0 OR INSTR(CONVERT(`msg_variables` USING binary), 0xC3B1) > 0 OR INSTR(CONVERT(`msg_variables` USING binary), 0xC3A1) > 0 OR INSTR(CONVERT(`msg_variables` USING binary), 0xC3AD) > 0 OR INSTR(CONVERT(`msg_variables` USING binary), 0xC2BF) > 0 OR INSTR(CONVERT(`msg_variables` USING binary), 0xC3AC) > 0 OR INSTR(CONVERT(`msg_variables` USING binary), 0xC3A9) > 0');

CALL sai_convert_table('sai', 'mensajes_internos', 'latin1', 'utf8mb4_general_ci', '');
-- Restore UTF-8 that does not fit in latin1 in `sai`.`mensajes_internos`.`msg_mensaje` (0xEFBFBD x10074, 0xEFB9A5 x36).
CALL sai_exec_if_charset('sai', 'mensajes_internos', 'msg_mensaje', 'utf8mb4', 'UPDATE `sai`.`mensajes_internos` SET `msg_mensaje` = REPLACE(REPLACE(`msg_mensaje`, CONVERT(0xEFBFBD USING latin1), CONVERT(0xEFBFBD USING utf8mb4)), CONVERT(0xEFB9A5 USING latin1), CONVERT(0xEFB9A5 USING utf8mb4)) WHERE INSTR(`msg_mensaje`, CONVERT(0xEFBFBD USING latin1)) > 0 OR INSTR(`msg_mensaje`, CONVERT(0xEFB9A5 USING latin1)) > 0');

-- Restore UTF-8 that does not fit in latin1 in `sai`.`mensajes_internos`.`msg_variables` (0xEFB9A5 x24, 0xEFBBBF x8).
CALL sai_exec_if_charset('sai', 'mensajes_internos', 'msg_variables', 'utf8mb4', 'UPDATE `sai`.`mensajes_internos` SET `msg_variables` = REPLACE(REPLACE(`msg_variables`, CONVERT(0xEFB9A5 USING latin1), CONVERT(0xEFB9A5 USING utf8mb4)), CONVERT(0xEFBBBF USING latin1), CONVERT(0xEFBBBF USING utf8mb4)) WHERE INSTR(`msg_variables`, CONVERT(0xEFB9A5 USING latin1)) > 0 OR INSTR(`msg_variables`, CONVERT(0xEFBBBF USING latin1)) > 0');


-- modulos: 4 character column(s): modulodesc, modulotextomenu, modulomostrar, modulotextomodific
CALL sai_convert_table('sai', 'modulos', 'latin1', 'utf8mb4_general_ci', '');

-- modulos_archivos: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'modulos_archivos', 'latin1', 'utf8mb4_general_ci', '');

-- nivel_estudios: 1 character column(s): nivest_descricpcion
CALL sai_convert_table('sai', 'nivel_estudios', 'latin1', 'utf8mb4_general_ci', '');

-- organismo_privado: 1 character column(s): orgapri_nombre
CALL sai_convert_table('sai', 'organismo_privado', 'latin1', 'utf8mb4_general_ci', '');

-- organismo_publico: 1 character column(s): orgapub_nombre
CALL sai_convert_table('sai', 'organismo_publico', 'latin1', 'utf8mb4_general_ci', '');

-- paises: 1 character column(s): paisnom
CALL sai_convert_table('sai', 'paises', 'latin1', 'utf8mb4_general_ci', '');

-- partidos: 3 character column(s): provinciacod, partidocod, partidonom
CALL sai_convert_table('sai', 'partidos', 'latin1', 'utf8mb4_general_ci', '');

-- persona: 5 character column(s): pers_cuilt, pers_nombre, pers_apellido, pers_sexo, pers_email
CALL sai_convert_table('sai', 'persona', 'latin1', 'utf8mb4_general_ci', '');

-- persona_temp: 5 character column(s): pers_cuilt, pers_nombre, pers_apellido, pers_sexo, pers_email
CALL sai_convert_table('sai', 'persona_temp', 'latin1', 'utf8mb4_general_ci', '');

-- poc: 1 character column(s): poc_obs
CALL sai_convert_table('sai', 'poc', 'latin1', 'utf8mb4_general_ci', '');

-- poc_actividad: 1 character column(s): pocact_nombre_tentativo
CALL sai_convert_table('sai', 'poc_actividad', 'latin1', 'utf8mb4_general_ci', '');

-- poc_actividad_actividad: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'poc_actividad_actividad', 'latin1', 'utf8mb4_general_ci', '');

-- poc_actividad_poc_objetivo: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'poc_actividad_poc_objetivo', 'latin1', 'utf8mb4_general_ci', '');

-- poc_area: 1 character column(s): pocarea_descripcion
CALL sai_convert_table('sai', 'poc_area', 'latin1', 'utf8mb4_general_ci', '');

-- poc_objetivo: 1 character column(s): pocobj_descripcion
CALL sai_convert_table('sai', 'poc_objetivo', 'latin1', 'utf8mb4_general_ci', '');

-- poc_poc_objetivo_poc_area: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'poc_poc_objetivo_poc_area', 'latin1', 'utf8mb4_general_ci', '');

-- poc_tipo_prestador: 1 character column(s): poctipopres_descripcion
CALL sai_convert_table('sai', 'poc_tipo_prestador', 'latin1', 'utf8mb4_general_ci', '');

-- ponderador_tipo_participacion_escalafon_nivel: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'ponderador_tipo_participacion_escalafon_nivel', 'latin1', 'utf8mb4_general_ci', '');

-- ponderador_tipo_ponderador: 1 character column(s): pondtipopond_descripcion
CALL sai_convert_table('sai', 'ponderador_tipo_ponderador', 'latin1', 'utf8mb4_general_ci', '');

-- prestador_docente: 24 character column(s): presdoc_nombre, presdoc_apellido, presdoc_password, presdoc_sexo, presdoc_eventual, presdoc_cuilt, presdoc_telefono, presdoc_celular, presdoc_email, presdoc_calle, presdoc_numero, presdoc_piso, presdoc_cp, presdoc_prov_codigo, presdoc_part_loca_descripcion, presdoc_cargo, presdoc_historial, presdoc_eve_organismo, presdoc_ult_titulo, presdoc_ult_titulo_institucion, presdoc_ult_titulo_ano, presdoc_ido_competencias, presdoc_ido_instituciones, presdoc_cv
CALL sai_convert_table('sai', 'prestador_docente', 'latin1', 'utf8mb4_general_ci', '');

-- prestador_docente_area_especifica: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'prestador_docente_area_especifica', 'latin1', 'utf8mb4_general_ci', '');

-- prestador_docente_tipo_postulacion: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'prestador_docente_tipo_postulacion', 'latin1', 'utf8mb4_general_ci', '');

-- prestador_institucional: 11 character column(s): presins_nombre, presins_sede, presins_ra_apellido, presins_ra_nombre, presins_ra_domicilio, presins_ra_cp, presins_ra_prov_codigo, presins_ra_part_loca_descripcion, presins_ra_telefono, presins_ra_fax, presins_ra_email
CALL sai_convert_table('sai', 'prestador_institucional', 'latin1', 'utf8mb4_general_ci', '');

-- programa_curso_inap: 1 character column(s): progcur_descripcion
CALL sai_convert_table('sai', 'programa_curso_inap', 'latin1', 'utf8mb4_general_ci', '');

-- provincias: 2 character column(s): provinciacod, provincianom
CALL sai_convert_table('sai', 'provincias', 'latin1', 'utf8mb4_general_ci', '');

-- roles: 3 character column(s): rolnom, roldesc, rolselecjurisd
CALL sai_convert_table('sai', 'roles', 'latin1', 'utf8mb4_general_ci', '');

-- roles_abm_roles: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'roles_abm_roles', 'latin1', 'utf8mb4_general_ci', '');

-- roles_modulos: 1 character column(s): rolmodtipoasig
CALL sai_convert_table('sai', 'roles_modulos', 'latin1', 'utf8mb4_general_ci', '');

-- roles_tipo_actividad: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'roles_tipo_actividad', 'latin1', 'utf8mb4_general_ci', '');

-- sede: 1 character column(s): sede_descripcion
CALL sai_convert_table('sai', 'sede', 'latin1', 'utf8mb4_general_ci', '');

-- sessions: 2 character column(s): SessionID, DataValue
CALL sai_convert_table('sai', 'sessions', 'latin1', 'utf8mb4_general_ci', 'DYNAMIC');

-- sistema: 9 character column(s): sis_nombre, sis_descripcion, sis_activo, sis_observaciones, sis_basededatos, sis_usuario, sis_password, sis_aviso, sis_mensaje
CALL sai_convert_table('sai', 'sistema', 'latin1', 'utf8mb4_general_ci', '');

-- stored_procedures: 5 character column(s): spnombre, spoperacion, sptabla, spsqlstring, spobserv
CALL sai_convert_table('sai', 'stored_procedures', 'latin1', 'utf8mb4_general_ci', 'DYNAMIC');

-- tipo_actividad: 3 character column(s): tipoact_nom, tipoact_descripcion, tipoact_norma_legal
CALL sai_convert_table('sai', 'tipo_actividad', 'latin1', 'utf8mb4_general_ci', '');

-- tipo_certificacion: 1 character column(s): tipocert_descripcion
CALL sai_convert_table('sai', 'tipo_certificacion', 'latin1', 'utf8mb4_general_ci', '');

-- tipo_inscripcion: 1 character column(s): tipoins_descripcion
CALL sai_convert_table('sai', 'tipo_inscripcion', 'latin1', 'utf8mb4_general_ci', '');

-- tipo_participacion: 1 character column(s): tipopart_descripcion
CALL sai_convert_table('sai', 'tipo_participacion', 'latin1', 'utf8mb4_general_ci', '');

-- tipo_ponderador: 2 character column(s): tipopond_descripcion, tipopond_nom
CALL sai_convert_table('sai', 'tipo_ponderador', 'latin1', 'utf8mb4_general_ci', '');

-- tipo_postulacion: 1 character column(s): tipopos_descricpcion
CALL sai_convert_table('sai', 'tipo_postulacion', 'latin1', 'utf8mb4_general_ci', '');

-- tipoact_agrega_tipoact: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'tipoact_agrega_tipoact', 'latin1', 'utf8mb4_general_ci', '');

-- universidad: 1 character column(s): univ_descripcion
CALL sai_convert_table('sai', 'universidad', 'latin1', 'utf8mb4_general_ci', '');

-- universidad_carrera: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'universidad_carrera', 'latin1', 'utf8mb4_general_ci', '');

-- usuario_universidad: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'usuario_universidad', 'latin1', 'utf8mb4_general_ci', '');

-- usuarios: 6 character column(s): usuarioCUIT, usuarionombre, usuarioapellido, usuariopassword, usuarioemail, usuariodioalta
CALL sai_convert_table('sai', 'usuarios', 'latin1', 'utf8mb4_general_ci', '');

-- usuarios2: 6 character column(s): usuarioCUIT, usuarionombre, usuarioapellido, usuariopassword, usuarioemail, usuariodioalta
CALL sai_convert_table('sai', 'usuarios2', 'latin1', 'utf8mb4_general_ci', '');

-- usuarios_enlace_jurisdiccion_inap: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'usuarios_enlace_jurisdiccion_inap', 'latin1', 'utf8mb4_general_ci', '');

-- usuarios_roles_jurisdiccion_inap: 3 character column(s): usuroljur_domicilio, usuroljur_telefono, usuroljur_fax
CALL sai_convert_table('sai', 'usuarios_roles_jurisdiccion_inap', 'latin1', 'utf8mb4_general_ci', '');

-- usuarios_roles_jurisdiccion_inap_modulos: 0 character column(s): (no character columns)
CALL sai_convert_table('sai', 'usuarios_roles_jurisdiccion_inap_modulos', 'latin1', 'utf8mb4_general_ci', '');

-- tabgralessai: latin1, no double-encoded column values.
-- constantes_grales: 5 character column(s): sistemanom, constantetipo, constantecod, constantenom, constantedesc
CALL sai_convert_table('tabgralessai', 'constantes_grales', 'latin1', 'utf8mb4_general_ci', '');

-- jurisdicciones: 7 character column(s): jurisdnom, jurisdcod01, jurisdcod02, jurisdobserv, jurisdarbolorden, jurisdarboltiponodo, jurisdtipo
CALL sai_convert_table('tabgralessai', 'jurisdicciones', 'latin1', 'utf8mb4_general_ci', '');

-- jurisdicciones2: 7 character column(s): jurisdnom, jurisdcod01, jurisdcod02, jurisdobserv, jurisdarbolorden, jurisdarboltiponodo, jurisdtipo
CALL sai_convert_table('tabgralessai', 'jurisdicciones2', 'latin1', 'utf8mb4_general_ci', '');

-- roles: 3 character column(s): rolnom, roldesc, rolglobal
CALL sai_convert_table('tabgralessai', 'roles', 'latin1', 'utf8mb4_general_ci', '');

-- sistema: 9 character column(s): sis_nombre, sis_descripcion, sis_activo, sis_observaciones, sis_basededatos, sis_usuario, sis_password, sis_aviso, sis_mensaje
CALL sai_convert_table('tabgralessai', 'sistema', 'latin1', 'utf8mb4_general_ci', '');

-- stored_procedures: 5 character column(s): spnombre, spoperacion, sptabla, spsqlstring, spobserv
CALL sai_convert_table('tabgralessai', 'stored_procedures', 'latin1', 'utf8mb4_general_ci', 'DYNAMIC');

-- tipoorganismos: 2 character column(s): tipoorgnom, tipoorgdesc
CALL sai_convert_table('tabgralessai', 'tipoorganismos', 'latin1', 'utf8mb4_general_ci', '');

-- usuarios: 6 character column(s): usuarionom, usuariopassword, usuarioapellido, usuarionombre, usuarioemail, jurisdcod
CALL sai_convert_table('tabgralessai', 'usuarios', 'latin1', 'utf8mb4_general_ci', '');

-- tabgrales2: already utf8. Widen only. A latin1 collation here is refused.
-- aperturas: 2 character column(s): aperturadesc, aperturamostrar
CALL sai_convert_table('tabgrales2', 'aperturas', 'utf8', 'utf8mb4_general_ci', '');

-- archivos: 1 character column(s): archivonom
CALL sai_convert_table('tabgrales2', 'archivos', 'utf8', 'utf8mb4_general_ci', '');

-- categorias_00001: 2 character column(s): catnom, catniveldup
CALL sai_convert_table('tabgrales2', 'categorias_00001', 'utf8', 'utf8mb4_general_ci', '');

-- colores: 2 character column(s): colordesc, colorhexa
CALL sai_convert_table('tabgrales2', 'colores', 'utf8', 'utf8mb4_general_ci', '');

-- constantes_grales: 5 character column(s): sistemanom, constantetipo, constantecod, constantenom, constantedesc
CALL sai_convert_table('tabgrales2', 'constantes_grales', 'utf8', 'utf8mb4_general_ci', '');

-- gruposmod: 1 character column(s): grupomodtextomenu
CALL sai_convert_table('tabgrales2', 'gruposmod', 'utf8', 'utf8mb4_general_ci', '');

-- gruposmod_modulos: 0 character column(s): (no character columns)
CALL sai_convert_table('tabgrales2', 'gruposmod_modulos', 'utf8', 'utf8mb4_general_ci', '');

-- jurisdicciones_00001: 5 character column(s): jurisdnom, jurisdcod01, jurisdobj, jurisdrespprim, jurisdacciones
CALL sai_convert_table('tabgrales2', 'jurisdicciones_00001', 'utf8', 'utf8mb4_general_ci', '');

-- jurisdicciones_tmp: 7 character column(s): jurisdnom, jurisdcod01, jurisdcod02, jurisdobserv, jurisdarbolorden, jurisdarboltiponodo, jurisdtipo
CALL sai_convert_table('tabgrales2', 'jurisdicciones_tmp', 'utf8', 'utf8mb4_general_ci', '');

-- log_mensajes: 1 character column(s): descripcion
CALL sai_convert_table('tabgrales2', 'log_mensajes', 'utf8', 'utf8mb4_general_ci', '');

-- log_modificaciones_00001: 9 character column(s): versionestado, logtabla, logtablaid, logtipomov, lognombrecampo, njurnumero, njurdesc, njurlink, logobservaciones
CALL sai_convert_table('tabgrales2', 'log_modificaciones_00001', 'utf8', 'utf8mb4_general_ci', '');

-- logusuarios: 3 character column(s): acciondesc, numeroip, archivonom
CALL sai_convert_table('tabgrales2', 'logusuarios', 'utf8', 'utf8mb4_general_ci', '');

-- modulos: 3 character column(s): modulodesc, modulotextomenu, modulomostrar
CALL sai_convert_table('tabgrales2', 'modulos', 'utf8', 'utf8mb4_general_ci', '');

-- modulos_archivos: 0 character column(s): (no character columns)
CALL sai_convert_table('tabgrales2', 'modulos_archivos', 'utf8', 'utf8mb4_general_ci', '');

-- normas_juridicas_00001: 3 character column(s): njurnumero, njurdesc, njurlink
CALL sai_convert_table('tabgrales2', 'normas_juridicas_00001', 'utf8', 'utf8mb4_general_ci', '');

-- normas_juridicas_tipos: 1 character column(s): normajuridtiponom
CALL sai_convert_table('tabgrales2', 'normas_juridicas_tipos', 'utf8', 'utf8mb4_general_ci', '');

-- rel_cat_cat_00001: 0 character column(s): (no character columns)
CALL sai_convert_table('tabgrales2', 'rel_cat_cat_00001', 'utf8', 'utf8mb4_general_ci', '');

-- rel_torg_torg_00001: 0 character column(s): (no character columns)
CALL sai_convert_table('tabgrales2', 'rel_torg_torg_00001', 'utf8', 'utf8mb4_general_ci', '');

-- roles: 2 character column(s): rolnom, roldesc
CALL sai_convert_table('tabgrales2', 'roles', 'utf8', 'utf8mb4_general_ci', '');

-- roles_abm_roles: 0 character column(s): (no character columns)
CALL sai_convert_table('tabgrales2', 'roles_abm_roles', 'utf8', 'utf8mb4_general_ci', '');

-- roles_modulos: 0 character column(s): (no character columns)
CALL sai_convert_table('tabgrales2', 'roles_modulos', 'utf8', 'utf8mb4_general_ci', '');

-- sessions: 2 character column(s): SessionID, DataValue
CALL sai_convert_table('tabgrales2', 'sessions', 'utf8', 'utf8mb4_general_ci', 'DYNAMIC');

-- sistema: 9 character column(s): sis_nombre, sis_descripcion, sis_activo, sis_observaciones, sis_basededatos, sis_usuario, sis_password, sis_aviso, sis_mensaje
CALL sai_convert_table('tabgrales2', 'sistema', 'utf8', 'utf8mb4_general_ci', '');

-- stored_procedures: 5 character column(s): spnombre, spoperacion, sptabla, spsqlstring, spobserv
CALL sai_convert_table('tabgrales2', 'stored_procedures', 'utf8', 'utf8mb4_general_ci', 'DYNAMIC');

-- tiposorganismos_00001: 2 character column(s): torgnom, torgcod
CALL sai_convert_table('tabgrales2', 'tiposorganismos_00001', 'utf8', 'utf8mb4_general_ci', '');

-- usuarios: 5 character column(s): usuarioCUIT, usuariopassword, usuarionombre, usuarioapellido, usuarioemail
CALL sai_convert_table('tabgrales2', 'usuarios', 'utf8', 'utf8mb4_general_ci', '');

-- usuarios_roles: 0 character column(s): (no character columns)
CALL sai_convert_table('tabgrales2', 'usuarios_roles', 'utf8', 'utf8mb4_general_ci', '');

-- versiones: 3 character column(s): versionref, versionobserv, versiontabla
CALL sai_convert_table('tabgrales2', 'versiones', 'utf8', 'utf8mb4_general_ci', '');

-- Table comments. These 28 sequences are not column values. The import stores
-- the dump text, so the comment would read as mojibake. Rewrite the comment
-- from the repaired UTF-8 bytes. ALTER COMMENT does not accept CONVERT(), so
-- sai_set_comment quotes the literal and prepares the statement.
CALL sai_set_comment('sai', 'actividad_autodesarrollo_persona', 0x4167656E74657320636F6E206372C3A96469746F73206465206175746F6465736172726F6C6C6F);
CALL sai_set_comment('sai', 'actividad_curso_diseno_inap', 0x41637469766964616420437572736F2044697365C3B16F20496E6170);
CALL sai_set_comment('sai', 'actividad_curso_diseno_institucional', 0x41637469766964616420437572736F2044697365C3B16F20496E737469747563696F6E616C);
CALL sai_set_comment('sai', 'actividad_curso_diseno_institucional_persona', 0x4167656E74657320636F6E206372C3A96469746F7320706F7220416374697669646164657320496E737469747563696F6E616C6573);
CALL sai_set_comment('sai', 'actividad_curso_diseno_jurisdiccional', 0x41637469766964616420437572736F2044697365C3B16F204573706563696669636F);
CALL sai_set_comment('sai', 'actividad_externa_persona', 0x4167656E74657320636F6E206372C3A96469746F7320706F722041637469766964616465732065787465726E6173202D204172742037);
CALL sai_set_comment('sai', 'area_especifica', 0x417265617320646520436F6D706574656E636961204573706563C3AD666963612064656C20507265737461646F7220446F63656E7465);
CALL sai_set_comment('sai', 'comision_fecha', 0x46656368617320646520756E6120636F6D697369C3B36E);
CALL sai_set_comment('sai', 'comision_persona', 0x436F6D697369C3B36E20696E7363726970746F73);
CALL sai_set_comment('sai', 'comision_persona_candidato', 0x436F6D697369C3B36E20696E7363726970746F73);
CALL sai_set_comment('sai', 'comision_prestador_docente', 0x436F6D697369C3B36E20707265737461646F7220646F63656E7465);
CALL sai_set_comment('sai', 'constantes_grales', 0x446573637269706369C3B36E20646520636F6E7374616E7465732067656E6572616C65732064652073697374656D61);
CALL sai_set_comment('sai', 'disposicion', 0x446973706F73696369C3B36E);
CALL sai_set_comment('sai', 'escalafones_agrup_niveles_grados', 0x52656C6163696F6E65732076C3A16C6964617320657363616C61666F6E65732D6167727570616D69656E746F732D6E6976656C65732D677261646F73);
CALL sai_set_comment('sai', 'evaluacion', 0x4576616C756163696F6E65732028436F6E64696369C3B36E2064652066696E616C697A616369C3B36E20646520756E206167656E746520656E20756E);
CALL sai_set_comment('sai', 'gruposmod', 0x477275706F73206465204DC3B364756C6F73);
CALL sai_set_comment('sai', 'gruposmod_modulos', 0x52656C616369C3B36E20677275706F73206465206DC3B364756C6F73);
CALL sai_set_comment('sai', 'modulos_archivos', 0x52656C616369C3B36E206D6F64756C6F73206172636869766F73);
CALL sai_set_comment('sai', 'prestador_docente_tipo_postulacion', 0x52656C6163696F6E20656E746520507265737461646F7220446F63656E7465207920737520706F7374756C616369C3B36E);
CALL sai_set_comment('sai', 'roles_modulos', 0x52656C616369C3B36E20726F6C65732079206DC3B364756C6F73);
CALL sai_set_comment('sai', 'sede', 0x53656465206465206C6120436F6D697369C3B36E2028494E415020446961676F6E616C2F494E41502042656C6772616E6F2F4F747261204578746572);
CALL sai_set_comment('sai', 'tipo_certificacion', 0x5469706F206465206365727469666963616369C3B36E);
CALL sai_set_comment('sai', 'tipo_inscripcion', 0x5469706F20646520696E736372697063696F6E20656E206C6120436F6D697369C3B36E2028616269657274612F6365727261646129);
CALL sai_set_comment('sai', 'tipo_participacion', 0x5469706F206465205061727469636970616369C3B36E);
CALL sai_set_comment('sai', 'usuarios_enlace_jurisdiccion_inap', 0x5573756172696F20456E6C616365206465206C61204A757269736469636369C3B36E);

-- Foreign keys, same columns and RESTRICT rules as the dump.
ALTER TABLE `sai`.`actividad_autodesarrollo` ADD CONSTRAINT `actividad_autodesarrollo_ibfk_1` FOREIGN KEY (`act_codigo`) REFERENCES `sai`.`actividad` (`act_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_autodesarrollo` ADD CONSTRAINT `actividad_autodesarrollo_ibfk_2` FOREIGN KEY (`tipoact_codigo`) REFERENCES `sai`.`tipo_actividad` (`tipoact_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_autodesarrollo_dictamen` ADD CONSTRAINT `actividad_autodesarrollo_dictamen_ibfk_3` FOREIGN KEY (`dic_codigo`) REFERENCES `sai`.`dictamen` (`dic_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_autodesarrollo_dictamen` ADD CONSTRAINT `actividad_autodesarrollo_dictamen_ibfk_4` FOREIGN KEY (`act_codigo`, `pers_codigo`) REFERENCES `sai`.`actividad_autodesarrollo_persona` (`act_codigo`, `pers_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_autodesarrollo_evento` ADD CONSTRAINT `actividad_autodesarrollo_evento_ibfk_12` FOREIGN KEY (`pais_codigo`) REFERENCES `sai`.`paises` (`paiscod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_autodesarrollo_evento` ADD CONSTRAINT `actividad_autodesarrollo_evento_ibfk_13` FOREIGN KEY (`prov_codigo`) REFERENCES `sai`.`provincias` (`provinciacod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_autodesarrollo_evento` ADD CONSTRAINT `actividad_autodesarrollo_evento_ibfk_14` FOREIGN KEY (`orgapri_codigo`) REFERENCES `sai`.`organismo_privado` (`orgapri_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_autodesarrollo_evento` ADD CONSTRAINT `actividad_autodesarrollo_evento_ibfk_15` FOREIGN KEY (`orgapub_codigo`) REFERENCES `sai`.`organismo_publico` (`orgapub_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_autodesarrollo_persona` ADD CONSTRAINT `actividad_autodesarrollo_persona_ibfk_32` FOREIGN KEY (`act_codigo`) REFERENCES `sai`.`actividad_autodesarrollo` (`act_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_autodesarrollo_persona` ADD CONSTRAINT `actividad_autodesarrollo_persona_ibfk_33` FOREIGN KEY (`pers_codigo`) REFERENCES `sai`.`persona` (`pers_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_autodesarrollo_persona` ADD CONSTRAINT `actividad_autodesarrollo_persona_ibfk_34` FOREIGN KEY (`tipopart_codigo`) REFERENCES `sai`.`tipo_participacion` (`tipopart_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_autodesarrollo_persona` ADD CONSTRAINT `actividad_autodesarrollo_persona_ibfk_35` FOREIGN KEY (`exp_codigo`) REFERENCES `sai`.`expediente` (`exp_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_autodesarrollo_persona` ADD CONSTRAINT `actividad_autodesarrollo_persona_ibfk_37` FOREIGN KEY (`agfunc_codigo`) REFERENCES `sai`.`agente_funcion` (`agfunc_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_autodesarrollo_persona` ADD CONSTRAINT `actividad_autodesarrollo_persona_ibfk_38` FOREIGN KEY (`orgapub_codigo`) REFERENCES `sai`.`organismo_publico` (`orgapub_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_autodesarrollo_persona` ADD CONSTRAINT `actividad_autodesarrollo_persona_ibfk_40` FOREIGN KEY (`jurisdid_inap`) REFERENCES `sai`.`jurisdiccion_inap` (`jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_autodesarrollo_persona` ADD CONSTRAINT `actividad_autodesarrollo_persona_ibfk_41` FOREIGN KEY (`escalafcod`, `agrupcod`, `escalafnivcod`, `escalafgradocod`) REFERENCES `sai`.`escalafones_agrup_niveles_grados` (`escalafcod`, `agrupcod`, `escalafnivcod`, `escalafgradocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso` ADD CONSTRAINT `actividad_curso_ibfk_1` FOREIGN KEY (`act_codigo`) REFERENCES `sai`.`actividad` (`act_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso` ADD CONSTRAINT `actividad_curso_ibfk_3` FOREIGN KEY (`tipoact_codigo`) REFERENCES `sai`.`tipo_actividad` (`tipoact_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso` ADD CONSTRAINT `actividad_curso_ibfk_4` FOREIGN KEY (`jurisdid_inap`) REFERENCES `sai`.`jurisdiccion_inap` (`jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_inap` ADD CONSTRAINT `actividad_curso_diseno_inap_ibfk_1` FOREIGN KEY (`act_codigo`) REFERENCES `sai`.`actividad_curso` (`act_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_inap` ADD CONSTRAINT `actividad_curso_diseno_inap_ibfk_2` FOREIGN KEY (`progcur_codigo`) REFERENCES `sai`.`programa_curso_inap` (`progcur_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_inap` ADD CONSTRAINT `actividad_curso_diseno_inap_ibfk_3` FOREIGN KEY (`areacur_codigo`) REFERENCES `sai`.`area_curso_inap` (`areacur_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_inap` ADD CONSTRAINT `actividad_curso_diseno_inap_ibfk_4` FOREIGN KEY (`univ_codigo`) REFERENCES `sai`.`universidad` (`univ_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional` ADD CONSTRAINT `actividad_curso_diseno_institucional_ibfk_10` FOREIGN KEY (`pais_codigo`) REFERENCES `sai`.`paises` (`paiscod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional` ADD CONSTRAINT `actividad_curso_diseno_institucional_ibfk_11` FOREIGN KEY (`prov_codigo`) REFERENCES `sai`.`provincias` (`provinciacod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional` ADD CONSTRAINT `actividad_curso_diseno_institucional_ibfk_12` FOREIGN KEY (`orgapri_codigo`) REFERENCES `sai`.`organismo_privado` (`orgapri_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional` ADD CONSTRAINT `actividad_curso_diseno_institucional_ibfk_13` FOREIGN KEY (`orgapub_codigo`) REFERENCES `sai`.`organismo_publico` (`orgapub_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional` ADD CONSTRAINT `actividad_curso_diseno_institucional_ibfk_9` FOREIGN KEY (`act_codigo`) REFERENCES `sai`.`actividad_curso` (`act_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional_persona` ADD CONSTRAINT `actividad_curso_diseno_institucional_persona_ibfk_10` FOREIGN KEY (`orgapub_codigo`) REFERENCES `sai`.`organismo_publico` (`orgapub_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional_persona` ADD CONSTRAINT `actividad_curso_diseno_institucional_persona_ibfk_11` FOREIGN KEY (`agfunc_codigo`) REFERENCES `sai`.`agente_funcion` (`agfunc_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional_persona` ADD CONSTRAINT `actividad_curso_diseno_institucional_persona_ibfk_12` FOREIGN KEY (`escalafcod`, `agrupcod`, `escalafnivcod`, `escalafgradocod`) REFERENCES `sai`.`escalafones_agrup_niveles_grados` (`escalafcod`, `agrupcod`, `escalafnivcod`, `escalafgradocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional_persona` ADD CONSTRAINT `actividad_curso_diseno_institucional_persona_ibfk_6` FOREIGN KEY (`act_codigo`) REFERENCES `sai`.`actividad_curso_diseno_institucional` (`act_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional_persona` ADD CONSTRAINT `actividad_curso_diseno_institucional_persona_ibfk_7` FOREIGN KEY (`pers_codigo`) REFERENCES `sai`.`persona` (`pers_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional_persona` ADD CONSTRAINT `actividad_curso_diseno_institucional_persona_ibfk_8` FOREIGN KEY (`jurisdid_inap`) REFERENCES `sai`.`jurisdiccion_inap` (`jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_institucional_persona` ADD CONSTRAINT `actividad_curso_diseno_institucional_persona_ibfk_9` FOREIGN KEY (`escalafcod`) REFERENCES `sai`.`escalafones_agrup_niveles_grados` (`escalafcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_diseno_jurisdiccional` ADD CONSTRAINT `actividad_curso_diseno_jurisdiccional_ibfk_1` FOREIGN KEY (`act_codigo`) REFERENCES `sai`.`actividad_curso` (`act_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_prestador_docente` ADD CONSTRAINT `actividad_curso_prestador_docente_ibfk_1` FOREIGN KEY (`act_codigo`) REFERENCES `sai`.`actividad_curso` (`act_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_curso_prestador_docente` ADD CONSTRAINT `actividad_curso_prestador_docente_ibfk_2` FOREIGN KEY (`presdoc_codigo`) REFERENCES `sai`.`prestador_docente` (`presdoc_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_eformal` ADD CONSTRAINT `actividad_eformal_ibfk_1` FOREIGN KEY (`act_codigo`) REFERENCES `sai`.`actividad` (`act_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_eformal` ADD CONSTRAINT `actividad_eformal_ibfk_2` FOREIGN KEY (`tipoact_codigo`) REFERENCES `sai`.`tipo_actividad` (`tipoact_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_eformal_persona` ADD CONSTRAINT `actividad_eformal_persona_ibfk_1` FOREIGN KEY (`escalafcod`, `agrupcod`, `escalafnivcod`, `escalafgradocod`) REFERENCES `sai`.`escalafones_agrup_niveles_grados` (`escalafcod`, `agrupcod`, `escalafnivcod`, `escalafgradocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_eformal_persona` ADD CONSTRAINT `actividad_eformal_persona_ibfk_2` FOREIGN KEY (`act_codigo`) REFERENCES `sai`.`actividad_eformal` (`act_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_externa` ADD CONSTRAINT `actividad_externa_ibfk_17` FOREIGN KEY (`act_codigo`) REFERENCES `sai`.`actividad` (`act_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_externa` ADD CONSTRAINT `actividad_externa_ibfk_18` FOREIGN KEY (`tipoact_codigo`) REFERENCES `sai`.`tipo_actividad` (`tipoact_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_externa` ADD CONSTRAINT `actividad_externa_ibfk_19` FOREIGN KEY (`pais_codigo`) REFERENCES `sai`.`paises` (`paiscod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_externa` ADD CONSTRAINT `actividad_externa_ibfk_20` FOREIGN KEY (`prov_codigo`) REFERENCES `sai`.`provincias` (`provinciacod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_externa` ADD CONSTRAINT `actividad_externa_ibfk_21` FOREIGN KEY (`orgapri_codigo`) REFERENCES `sai`.`organismo_privado` (`orgapri_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_externa` ADD CONSTRAINT `actividad_externa_ibfk_22` FOREIGN KEY (`orgapub_codigo`) REFERENCES `sai`.`organismo_publico` (`orgapub_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_externa_persona` ADD CONSTRAINT `actividad_externa_persona_ibfk_10` FOREIGN KEY (`escalafcod`, `agrupcod`, `escalafnivcod`, `escalafgradocod`) REFERENCES `sai`.`escalafones_agrup_niveles_grados` (`escalafcod`, `agrupcod`, `escalafnivcod`, `escalafgradocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_externa_persona` ADD CONSTRAINT `actividad_externa_persona_ibfk_2` FOREIGN KEY (`exp_codigo`) REFERENCES `sai`.`expediente` (`exp_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_externa_persona` ADD CONSTRAINT `actividad_externa_persona_ibfk_4` FOREIGN KEY (`orgapub_codigo`) REFERENCES `sai`.`organismo_publico` (`orgapub_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_externa_persona` ADD CONSTRAINT `actividad_externa_persona_ibfk_6` FOREIGN KEY (`act_codigo`, `actprog_sec`) REFERENCES `sai`.`actividad_programacion` (`act_codigo`, `actprog_sec`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_externa_persona` ADD CONSTRAINT `actividad_externa_persona_ibfk_7` FOREIGN KEY (`agfunc_codigo`) REFERENCES `sai`.`agente_funcion` (`agfunc_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_externa_persona` ADD CONSTRAINT `actividad_externa_persona_ibfk_9` FOREIGN KEY (`jurisdid_inap`) REFERENCES `sai`.`jurisdiccion_inap` (`jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_formato_actividad` ADD CONSTRAINT `actividad_formato_actividad_ibfk_1` FOREIGN KEY (`act_codigo`) REFERENCES `sai`.`actividad` (`act_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_formato_actividad` ADD CONSTRAINT `actividad_formato_actividad_ibfk_2` FOREIGN KEY (`formact_codigo`) REFERENCES `sai`.`formato_actividad` (`formact_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_programacion` ADD CONSTRAINT `actividad_programacion_ibfk_1` FOREIGN KEY (`act_codigo`) REFERENCES `sai`.`actividad` (`act_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_programacion` ADD CONSTRAINT `actividad_programacion_ibfk_2` FOREIGN KEY (`dic_codigo`) REFERENCES `sai`.`dictamen` (`dic_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`actividad_programacion` ADD CONSTRAINT `actividad_programacion_ibfk_3` FOREIGN KEY (`exp_codigo`) REFERENCES `sai`.`expediente` (`exp_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`agente` ADD CONSTRAINT `agente_ibfk_1` FOREIGN KEY (`pers_codigo`) REFERENCES `sai`.`persona` (`pers_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`agente` ADD CONSTRAINT `agente_ibfk_3` FOREIGN KEY (`agfunc_codigo`) REFERENCES `sai`.`agente_funcion` (`agfunc_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`agente` ADD CONSTRAINT `agente_ibfk_5` FOREIGN KEY (`orgapub_codigo`) REFERENCES `sai`.`organismo_publico` (`orgapub_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`agente` ADD CONSTRAINT `agente_ibfk_6` FOREIGN KEY (`jurisdid_inap`) REFERENCES `sai`.`jurisdiccion_inap` (`jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`agente` ADD CONSTRAINT `agente_ibfk_7` FOREIGN KEY (`escalafcod`, `agrupcod`, `escalafnivcod`, `escalafgradocod`) REFERENCES `sai`.`escalafones_agrup_niveles_grados` (`escalafcod`, `agrupcod`, `escalafnivcod`, `escalafgradocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`agente_temp` ADD CONSTRAINT `agente_temp_ibfk_1` FOREIGN KEY (`pers_codigo`) REFERENCES `sai`.`persona_temp` (`pers_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`agente_temp` ADD CONSTRAINT `agente_temp_ibfk_2` FOREIGN KEY (`escalafcod`) REFERENCES `sai`.`escalafones` (`escalafcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`agente_temp` ADD CONSTRAINT `agente_temp_ibfk_3` FOREIGN KEY (`agfunc_codigo`) REFERENCES `sai`.`agente_funcion` (`agfunc_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`agente_temp` ADD CONSTRAINT `agente_temp_ibfk_4` FOREIGN KEY (`jurisdid_inap`) REFERENCES `sai`.`jurisdiccion_inap` (`jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`agente_temp` ADD CONSTRAINT `agente_temp_ibfk_5` FOREIGN KEY (`orgapub_codigo`) REFERENCES `sai`.`organismo_publico` (`orgapub_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`agente_temp` ADD CONSTRAINT `agente_temp_ibfk_6` FOREIGN KEY (`escalafcod`, `agrupcod`, `escalafnivcod`, `escalafgradocod`) REFERENCES `sai`.`escalafones_agrup_niveles_grados` (`escalafcod`, `agrupcod`, `escalafnivcod`, `escalafgradocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision` ADD CONSTRAINT `comision_ibfk_10` FOREIGN KEY (`sede_codigo`) REFERENCES `sai`.`sede` (`sede_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision` ADD CONSTRAINT `comision_ibfk_11` FOREIGN KEY (`act_codigo`, `actprog_sec`) REFERENCES `sai`.`actividad_programacion` (`act_codigo`, `actprog_sec`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision` ADD CONSTRAINT `comision_ibfk_7` FOREIGN KEY (`tipoins_codigo`) REFERENCES `sai`.`tipo_inscripcion` (`tipoins_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision` ADD CONSTRAINT `comision_ibfk_8` FOREIGN KEY (`pais_codigo`) REFERENCES `sai`.`paises` (`paiscod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision` ADD CONSTRAINT `comision_ibfk_9` FOREIGN KEY (`prov_codigo`) REFERENCES `sai`.`provincias` (`provinciacod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision_fecha` ADD CONSTRAINT `comision_fecha_ibfk_1` FOREIGN KEY (`comi_codigo`) REFERENCES `sai`.`comision` (`comi_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision_persona` ADD CONSTRAINT `comision_persona_ibfk_1` FOREIGN KEY (`comi_codigo`) REFERENCES `sai`.`comision` (`comi_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision_persona` ADD CONSTRAINT `comision_persona_ibfk_2` FOREIGN KEY (`pers_codigo`) REFERENCES `sai`.`persona` (`pers_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision_persona` ADD CONSTRAINT `comision_persona_ibfk_4` FOREIGN KEY (`agfunc_codigo`) REFERENCES `sai`.`agente_funcion` (`agfunc_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision_persona` ADD CONSTRAINT `comision_persona_ibfk_5` FOREIGN KEY (`eval_codigo`) REFERENCES `sai`.`evaluacion` (`eval_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision_persona` ADD CONSTRAINT `comision_persona_ibfk_7` FOREIGN KEY (`orgapub_codigo`) REFERENCES `sai`.`organismo_publico` (`orgapub_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision_persona` ADD CONSTRAINT `comision_persona_ibfk_8` FOREIGN KEY (`jurisdid_inap`) REFERENCES `sai`.`jurisdiccion_inap` (`jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision_persona` ADD CONSTRAINT `comision_persona_ibfk_9` FOREIGN KEY (`escalafcod`, `agrupcod`, `escalafnivcod`, `escalafgradocod`) REFERENCES `sai`.`escalafones_agrup_niveles_grados` (`escalafcod`, `agrupcod`, `escalafnivcod`, `escalafgradocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision_persona_candidato` ADD CONSTRAINT `comision_persona_candidato_ibfk_10` FOREIGN KEY (`escalafcod`) REFERENCES `sai`.`escalafones` (`escalafcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision_persona_candidato` ADD CONSTRAINT `comision_persona_candidato_ibfk_11` FOREIGN KEY (`agfunc_codigo`) REFERENCES `sai`.`agente_funcion` (`agfunc_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision_persona_candidato` ADD CONSTRAINT `comision_persona_candidato_ibfk_12` FOREIGN KEY (`jurisdid_inap`) REFERENCES `sai`.`jurisdiccion_inap` (`jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision_persona_candidato` ADD CONSTRAINT `comision_persona_candidato_ibfk_13` FOREIGN KEY (`orgapub_codigo`) REFERENCES `sai`.`organismo_publico` (`orgapub_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision_persona_candidato` ADD CONSTRAINT `comision_persona_candidato_ibfk_8` FOREIGN KEY (`comi_codigo`) REFERENCES `sai`.`comision` (`comi_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision_persona_candidato` ADD CONSTRAINT `comision_persona_candidato_ibfk_9` FOREIGN KEY (`pers_codigo`) REFERENCES `sai`.`persona` (`pers_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision_prestador_docente` ADD CONSTRAINT `comision_prestador_docente_ibfk_1` FOREIGN KEY (`act_codigo`, `presdoc_codigo`) REFERENCES `sai`.`actividad_curso_prestador_docente` (`act_codigo`, `presdoc_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`comision_prestador_docente` ADD CONSTRAINT `comision_prestador_docente_ibfk_2` FOREIGN KEY (`comi_codigo`, `act_codigo`) REFERENCES `sai`.`comision` (`comi_codigo`, `act_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`constantes_grales` ADD CONSTRAINT `constantes_grales_ibfk_1` FOREIGN KEY (`sistemanom`) REFERENCES `sai`.`sistema` (`sis_nombre`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`datos_documentos` ADD CONSTRAINT `dto_jurisdinap` FOREIGN KEY (`jurisdid_inap`) REFERENCES `sai`.`jurisdiccion_inap` (`jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`dictamen` ADD CONSTRAINT `dictamen_ibfk_1` FOREIGN KEY (`dis_codigo`) REFERENCES `sai`.`disposicion` (`dis_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`dictamen` ADD CONSTRAINT `dictamen_ibfk_2` FOREIGN KEY (`pondtipopond_codigo_cal_pres`) REFERENCES `sai`.`ponderador_tipo_ponderador` (`pondtipopond_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`dictamen` ADD CONSTRAINT `dictamen_ibfk_3` FOREIGN KEY (`pondtipopond_codigo_int`) REFERENCES `sai`.`ponderador_tipo_ponderador` (`pondtipopond_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`dictamen` ADD CONSTRAINT `dictamen_ibfk_4` FOREIGN KEY (`pondtipopond_codigo_proc_eva`) REFERENCES `sai`.`ponderador_tipo_ponderador` (`pondtipopond_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`escalafones_agrup_niveles_grados` ADD CONSTRAINT `escalafones_agrup_niveles_grados_ibfk_1` FOREIGN KEY (`escalafcod`) REFERENCES `sai`.`escalafones` (`escalafcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`escalafones_agrup_niveles_grados` ADD CONSTRAINT `escalafones_agrup_niveles_grados_ibfk_2` FOREIGN KEY (`agrupcod`) REFERENCES `sai`.`agrupamientos` (`agrupcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`escalafones_agrup_niveles_grados` ADD CONSTRAINT `escalafones_agrup_niveles_grados_ibfk_3` FOREIGN KEY (`escalafnivcod`) REFERENCES `sai`.`escalafones_niveles` (`escalafnivcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`escalafones_agrup_niveles_grados` ADD CONSTRAINT `escalafones_agrup_niveles_grados_ibfk_4` FOREIGN KEY (`escalafgradocod`) REFERENCES `sai`.`escalafones_grados` (`escalafgradocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`expediente` ADD CONSTRAINT `expediente_ibfk_1` FOREIGN KEY (`jurisdid_exp`) REFERENCES `sai`.`jurisdiccion_inap` (`jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`gruposmod_modulos` ADD CONSTRAINT `gruposmod_modulos_ibfk_1` FOREIGN KEY (`grupomodcod`) REFERENCES `sai`.`gruposmod` (`grupomodcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`gruposmod_modulos` ADD CONSTRAINT `gruposmod_modulos_ibfk_2` FOREIGN KEY (`modulocod`) REFERENCES `sai`.`modulos` (`modulocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`logusuarios` ADD CONSTRAINT `logusuarios_ibfk_1` FOREIGN KEY (`codigo_mensaje`) REFERENCES `sai`.`log_mensajes` (`codigo_mensaje`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`modulos` ADD CONSTRAINT `modulos_ibfk_1` FOREIGN KEY (`archivocod`) REFERENCES `sai`.`archivos` (`archivocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`modulos_archivos` ADD CONSTRAINT `modulos_archivos_ibfk_1` FOREIGN KEY (`archivocod`) REFERENCES `sai`.`archivos` (`archivocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`modulos_archivos` ADD CONSTRAINT `modulos_archivos_ibfk_2` FOREIGN KEY (`modulocod`) REFERENCES `sai`.`modulos` (`modulocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`poc` ADD CONSTRAINT `poc_ibfk_1` FOREIGN KEY (`jurisdid_inap`) REFERENCES `sai`.`jurisdiccion_inap` (`jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`poc_actividad` ADD CONSTRAINT `poc_actividad_ibfk_1` FOREIGN KEY (`poc_codigo`) REFERENCES `sai`.`poc` (`poc_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`poc_actividad` ADD CONSTRAINT `poc_actividad_ibfk_2` FOREIGN KEY (`poctipopres_codigo`) REFERENCES `sai`.`poc_tipo_prestador` (`poctipopres_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`poc_actividad_actividad` ADD CONSTRAINT `poc_actividad_actividad_ibfk_3` FOREIGN KEY (`pocact_codigo`) REFERENCES `sai`.`poc_actividad` (`pocact_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`poc_actividad_actividad` ADD CONSTRAINT `poc_actividad_actividad_ibfk_4` FOREIGN KEY (`act_codigo`) REFERENCES `sai`.`actividad` (`act_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`poc_actividad_poc_objetivo` ADD CONSTRAINT `poc_actividad_poc_objetivo_ibfk_1` FOREIGN KEY (`pocact_codigo`) REFERENCES `sai`.`poc_actividad` (`pocact_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`poc_actividad_poc_objetivo` ADD CONSTRAINT `poc_actividad_poc_objetivo_ibfk_2` FOREIGN KEY (`pocobj_codigo`) REFERENCES `sai`.`poc_objetivo` (`pocobj_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`poc_area` ADD CONSTRAINT `poc_area_ibfk_1` FOREIGN KEY (`jurisdid_inap`) REFERENCES `sai`.`jurisdiccion_inap` (`jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`poc_objetivo` ADD CONSTRAINT `poc_objetivo_ibfk_1` FOREIGN KEY (`jurisdid_inap`) REFERENCES `sai`.`jurisdiccion_inap` (`jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`poc_poc_objetivo_poc_area` ADD CONSTRAINT `poc_poc_objetivo_poc_area_ibfk_1` FOREIGN KEY (`poc_codigo`) REFERENCES `sai`.`poc` (`poc_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`poc_poc_objetivo_poc_area` ADD CONSTRAINT `poc_poc_objetivo_poc_area_ibfk_2` FOREIGN KEY (`pocobj_codigo`) REFERENCES `sai`.`poc_objetivo` (`pocobj_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`poc_poc_objetivo_poc_area` ADD CONSTRAINT `poc_poc_objetivo_poc_area_ibfk_3` FOREIGN KEY (`pocarea_codigo`) REFERENCES `sai`.`poc_area` (`pocarea_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`ponderador_tipo_participacion_escalafon_nivel` ADD CONSTRAINT `FK_ponderador_tipo_participacion_escalafon_nivel` FOREIGN KEY (`escalaftramocod`) REFERENCES `sai`.`escalafones_tramos` (`escalaftramocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`ponderador_tipo_participacion_escalafon_nivel` ADD CONSTRAINT `ponderador_tipo_participacion_escalafon_nivel_ibfk_1` FOREIGN KEY (`tipoact_codigo`) REFERENCES `sai`.`tipo_actividad` (`tipoact_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`ponderador_tipo_participacion_escalafon_nivel` ADD CONSTRAINT `ponderador_tipo_participacion_escalafon_nivel_ibfk_2` FOREIGN KEY (`tipopart_codigo`) REFERENCES `sai`.`tipo_participacion` (`tipopart_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`ponderador_tipo_participacion_escalafon_nivel` ADD CONSTRAINT `ponderador_tipo_participacion_escalafon_nivel_ibfk_3` FOREIGN KEY (`escalafnivcod`) REFERENCES `sai`.`escalafones_niveles` (`escalafnivcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`ponderador_tipo_ponderador` ADD CONSTRAINT `ponderador_tipo_ponderador_ibfk_1` FOREIGN KEY (`tipopond_codigo`) REFERENCES `sai`.`tipo_ponderador` (`tipopond_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`prestador_docente` ADD CONSTRAINT `prestador_docente_ibfk_21` FOREIGN KEY (`presdoc_origen_pais_codigo`) REFERENCES `sai`.`paises` (`paiscod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`prestador_docente` ADD CONSTRAINT `prestador_docente_ibfk_23` FOREIGN KEY (`presdoc_prov_codigo`) REFERENCES `sai`.`provincias` (`provinciacod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`prestador_docente` ADD CONSTRAINT `prestador_docente_ibfk_24` FOREIGN KEY (`presins_codigo`) REFERENCES `sai`.`prestador_institucional` (`presins_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`prestador_docente` ADD CONSTRAINT `prestador_docente_ibfk_25` FOREIGN KEY (`jurisdid_origen`) REFERENCES `sai`.`jurisdiccion_inap` (`jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`prestador_docente` ADD CONSTRAINT `prestador_docente_ibfk_26` FOREIGN KEY (`orgapub_codigo`) REFERENCES `sai`.`organismo_publico` (`orgapub_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`prestador_docente_area_especifica` ADD CONSTRAINT `prestador_docente_area_especifica_ibfk_17` FOREIGN KEY (`presdoc_codigo`) REFERENCES `sai`.`prestador_docente` (`presdoc_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`prestador_docente_area_especifica` ADD CONSTRAINT `prestador_docente_area_especifica_ibfk_18` FOREIGN KEY (`areagen_codigo`, `areaesp_codigo`) REFERENCES `sai`.`area_especifica` (`areagen_codigo`, `areaesp_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`prestador_docente_tipo_postulacion` ADD CONSTRAINT `prestador_docente_tipo_postulacion_ibfk_1` FOREIGN KEY (`presdoc_codigo`) REFERENCES `sai`.`prestador_docente` (`presdoc_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`prestador_docente_tipo_postulacion` ADD CONSTRAINT `prestador_docente_tipo_postulacion_ibfk_2` FOREIGN KEY (`tipopos_codigo`) REFERENCES `sai`.`tipo_postulacion` (`tipopos_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`prestador_institucional` ADD CONSTRAINT `prestador_institucional_ibfk_10` FOREIGN KEY (`presins_ra_prov_codigo`) REFERENCES `sai`.`provincias` (`provinciacod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`roles_abm_roles` ADD CONSTRAINT `roles_abm_roles_ibfk_1` FOREIGN KEY (`rolcodactualiza`) REFERENCES `sai`.`roles` (`rolcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`roles_abm_roles` ADD CONSTRAINT `roles_abm_roles_ibfk_2` FOREIGN KEY (`rolcodactualizado`) REFERENCES `sai`.`roles` (`rolcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`roles_modulos` ADD CONSTRAINT `roles_modulos_ibfk_1` FOREIGN KEY (`rolcod`) REFERENCES `sai`.`roles` (`rolcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`roles_modulos` ADD CONSTRAINT `roles_modulos_ibfk_2` FOREIGN KEY (`modulocod`) REFERENCES `sai`.`modulos` (`modulocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`roles_tipo_actividad` ADD CONSTRAINT `roles_tipo_actividad_ibfk_1` FOREIGN KEY (`tipoact_codigo`) REFERENCES `sai`.`tipo_actividad` (`tipoact_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`roles_tipo_actividad` ADD CONSTRAINT `roles_tipo_actividad_ibfk_2` FOREIGN KEY (`rolcod`) REFERENCES `sai`.`roles` (`rolcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`tipoact_agrega_tipoact` ADD CONSTRAINT `tipoact_agrega_tipoact_ibfk_3` FOREIGN KEY (`tipoact_origen`) REFERENCES `sai`.`tipo_actividad` (`tipoact_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`tipoact_agrega_tipoact` ADD CONSTRAINT `tipoact_agrega_tipoact_ibfk_4` FOREIGN KEY (`tipoact_agrega`) REFERENCES `sai`.`tipo_actividad` (`tipoact_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`tipo_actividad` ADD CONSTRAINT `tipo_actividad_ibfk_1` FOREIGN KEY (`formact_codigo`) REFERENCES `sai`.`formato_actividad` (`formact_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`tipo_participacion` ADD CONSTRAINT `tipo_participacion_ibfk_1` FOREIGN KEY (`tipoact_codigo`) REFERENCES `sai`.`tipo_actividad` (`tipoact_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`usuarios_enlace_jurisdiccion_inap` ADD CONSTRAINT `usuarios_enlace_jurisdiccion_inap_ibfk_1` FOREIGN KEY (`usuariocod`, `rolcod`) REFERENCES `sai`.`usuarios_roles_jurisdiccion_inap` (`usuariocod`, `rolcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`usuarios_roles_jurisdiccion_inap` ADD CONSTRAINT `usuarios_roles_jurisdiccion_inap_ibfk_1` FOREIGN KEY (`usuariocod`) REFERENCES `sai`.`usuarios` (`usuariocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`usuarios_roles_jurisdiccion_inap` ADD CONSTRAINT `usuarios_roles_jurisdiccion_inap_ibfk_2` FOREIGN KEY (`rolcod`) REFERENCES `sai`.`roles` (`rolcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`usuarios_roles_jurisdiccion_inap` ADD CONSTRAINT `usuarios_roles_jurisdiccion_inap_ibfk_3` FOREIGN KEY (`jurisdid_inap`) REFERENCES `sai`.`jurisdiccion_inap` (`jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`usuarios_roles_jurisdiccion_inap_modulos` ADD CONSTRAINT `usuarios_roles_jurisdiccion_inap_modulos_ibfk_1` FOREIGN KEY (`usuariocod`, `rolcod`, `jurisdid_inap`) REFERENCES `sai`.`usuarios_roles_jurisdiccion_inap` (`usuariocod`, `rolcod`, `jurisdid_inap`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`usuarios_roles_jurisdiccion_inap_modulos` ADD CONSTRAINT `usuarios_roles_jurisdiccion_inap_modulos_ibfk_2` FOREIGN KEY (`rolcod`, `modulocod`) REFERENCES `sai`.`roles_modulos` (`rolcod`, `modulocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`usuario_universidad` ADD CONSTRAINT `usuario_universidad_ibfk_1` FOREIGN KEY (`usuariocod`) REFERENCES `sai`.`usuarios` (`usuariocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `sai`.`usuario_universidad` ADD CONSTRAINT `usuario_universidad_ibfk_2` FOREIGN KEY (`univ_codigo`) REFERENCES `sai`.`universidad` (`univ_codigo`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`categorias_00001` ADD CONSTRAINT `categorias_00001_ibfk_3` FOREIGN KEY (`versionid`) REFERENCES `tabgrales2`.`versiones` (`versionid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`categorias_00001` ADD CONSTRAINT `categorias_00001_ibfk_4` FOREIGN KEY (`colorcod`) REFERENCES `tabgrales2`.`colores` (`colorcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`categorias_00001` ADD CONSTRAINT `categorias_00001_ibfk_5` FOREIGN KEY (`versionidinicial`) REFERENCES `tabgrales2`.`versiones` (`versionid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`constantes_grales` ADD CONSTRAINT `constantes_grales_ibfk_1` FOREIGN KEY (`sistemanom`) REFERENCES `tabgrales2`.`sistema` (`sis_nombre`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`gruposmod_modulos` ADD CONSTRAINT `gruposmod_modulos_ibfk_1` FOREIGN KEY (`grupomodcod`) REFERENCES `tabgrales2`.`gruposmod` (`grupomodcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`gruposmod_modulos` ADD CONSTRAINT `gruposmod_modulos_ibfk_2` FOREIGN KEY (`modulocod`) REFERENCES `tabgrales2`.`modulos` (`modulocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`jurisdicciones_00001` ADD CONSTRAINT `FK_jurisdicciones_00001` FOREIGN KEY (`versionid`, `torgid`) REFERENCES `tabgrales2`.`tiposorganismos_00001` (`versionid`, `torgid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`jurisdicciones_00001` ADD CONSTRAINT `jurisdicciones_00001_ibfk_1` FOREIGN KEY (`versionid`, `jurisdsuperior`) REFERENCES `tabgrales2`.`jurisdicciones_00001` (`versionid`, `jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`jurisdicciones_00001` ADD CONSTRAINT `jurisdicciones_00001_ibfk_7` FOREIGN KEY (`jurisdaperturacod`) REFERENCES `tabgrales2`.`aperturas` (`aperturacod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`jurisdicciones_00001` ADD CONSTRAINT `jurisdicciones_00001_ibfk_8` FOREIGN KEY (`versionidinicial`) REFERENCES `tabgrales2`.`versiones` (`versionid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`logusuarios` ADD CONSTRAINT `logusuarios_ibfk_1` FOREIGN KEY (`codigo_mensaje`) REFERENCES `tabgrales2`.`log_mensajes` (`codigo_mensaje`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`log_modificaciones_00001` ADD CONSTRAINT `log_modificaciones_00001_ibfk_1` FOREIGN KEY (`versionid`) REFERENCES `tabgrales2`.`versiones` (`versionid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`log_modificaciones_00001` ADD CONSTRAINT `log_modificaciones_00001_ibfk_2` FOREIGN KEY (`njurtipo`) REFERENCES `tabgrales2`.`normas_juridicas_tipos` (`normajuridtipocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`modulos` ADD CONSTRAINT `modulos_ibfk_1` FOREIGN KEY (`archivocod`) REFERENCES `tabgrales2`.`archivos` (`archivocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`modulos_archivos` ADD CONSTRAINT `modulos_archivos_ibfk_1` FOREIGN KEY (`archivocod`) REFERENCES `tabgrales2`.`archivos` (`archivocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`modulos_archivos` ADD CONSTRAINT `modulos_archivos_ibfk_2` FOREIGN KEY (`modulocod`) REFERENCES `tabgrales2`.`modulos` (`modulocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`normas_juridicas_00001` ADD CONSTRAINT `normas_juridicas_00001_ibfk_1` FOREIGN KEY (`versionid`, `jurisdid`) REFERENCES `tabgrales2`.`jurisdicciones_00001` (`versionid`, `jurisdid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`normas_juridicas_00001` ADD CONSTRAINT `normas_juridicas_00001_ibfk_2` FOREIGN KEY (`njurtipo`) REFERENCES `tabgrales2`.`normas_juridicas_tipos` (`normajuridtipocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`rel_cat_cat_00001` ADD CONSTRAINT `rel_cat_cat_00001_ibfk_1` FOREIGN KEY (`versionid`, `catid`) REFERENCES `tabgrales2`.`categorias_00001` (`versionid`, `catid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`rel_cat_cat_00001` ADD CONSTRAINT `rel_cat_cat_00001_ibfk_2` FOREIGN KEY (`versionid`, `relcatidpadre`) REFERENCES `tabgrales2`.`categorias_00001` (`versionid`, `catid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`rel_torg_torg_00001` ADD CONSTRAINT `rel_torg_torg_00001_ibfk_1` FOREIGN KEY (`versionid`, `torgid`) REFERENCES `tabgrales2`.`tiposorganismos_00001` (`versionid`, `torgid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`rel_torg_torg_00001` ADD CONSTRAINT `rel_torg_torg_00001_ibfk_2` FOREIGN KEY (`versionid`, `reltorgidpadre`) REFERENCES `tabgrales2`.`tiposorganismos_00001` (`versionid`, `torgid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`roles_abm_roles` ADD CONSTRAINT `roles_abm_roles_ibfk_1` FOREIGN KEY (`rolcodactualiza`) REFERENCES `tabgrales2`.`roles` (`rolcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`roles_abm_roles` ADD CONSTRAINT `roles_abm_roles_ibfk_2` FOREIGN KEY (`rolcodactualizado`) REFERENCES `tabgrales2`.`roles` (`rolcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`roles_modulos` ADD CONSTRAINT `roles_modulos_ibfk_1` FOREIGN KEY (`rolcod`) REFERENCES `tabgrales2`.`roles` (`rolcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`roles_modulos` ADD CONSTRAINT `roles_modulos_ibfk_2` FOREIGN KEY (`modulocod`) REFERENCES `tabgrales2`.`modulos` (`modulocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`tiposorganismos_00001` ADD CONSTRAINT `tiposorganismos_00001_ibfk_1` FOREIGN KEY (`versionid`, `catid`) REFERENCES `tabgrales2`.`categorias_00001` (`versionid`, `catid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`tiposorganismos_00001` ADD CONSTRAINT `tiposorganismos_00001_ibfk_2` FOREIGN KEY (`versionidinicial`) REFERENCES `tabgrales2`.`versiones` (`versionid`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`usuarios_roles` ADD CONSTRAINT `usuarios_roles_ibfk_1` FOREIGN KEY (`usuariocod`) REFERENCES `tabgrales2`.`usuarios` (`usuariocod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE `tabgrales2`.`usuarios_roles` ADD CONSTRAINT `usuarios_roles_ibfk_2` FOREIGN KEY (`rolcod`) REFERENCES `tabgrales2`.`roles` (`rolcod`) ON UPDATE RESTRICT ON DELETE RESTRICT;
DROP PROCEDURE IF EXISTS sai_exec_if_charset;
DROP PROCEDURE IF EXISTS sai_convert_table;
DROP PROCEDURE IF EXISTS sai_set_comment;
SET FOREIGN_KEY_CHECKS = @sai_old_fk;
SET UNIQUE_CHECKS = @sai_old_uq;
SET SQL_SAFE_UPDATES = @sai_old_safe;

