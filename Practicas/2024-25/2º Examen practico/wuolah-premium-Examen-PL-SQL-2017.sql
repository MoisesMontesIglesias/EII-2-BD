--TRIGGERS:
	--TANDA 1:
	--1: se debe mantener actualizado el presupuesto de los equipos (en lo que a subvenciones se refiere)
	create or replace TRIGGER "TRIGGER_PLSQL_T1_1" AFTER INSERT OR UPDATE OR DELETE ON ES_SUBVENCIONADO    
	FOR EACH ROW 
	BEGIN
		IF INSERTING THEN
			update equipo set presupuesto = presupuesto + :NEW.cantidad
				where :NEW.nombre_equipo = nombre_equipo;

		ELSIF UPDATING THEN
			update equipo set presupuesto = presupuesto - :OLD.cantidad + :NEW.cantidad
				where :NEW.nombre_equipo = nombre_equipo;

		ELSE
			update equipo set presupuesto = presupuesto - :OLD.cantidad
				where :OLD.nombre_equipo = nombre_equipo;

		END IF;
	END;
	
	--2: una etapa no puede discurrir por tramos en los que haya habido más de 3 incidentes
	create or replace TRIGGER "TRIGGER_PLSQL_T1_2" BEFORE INSERT OR UPDATE ON DISCURRE 
	FOR EACH ROW 
	DECLARE
		nIncidentes number;
	BEGIN
		select count(id_incidente) into nIncidentes
		from incidente
		where :NEW.id_carretera = incidente.id_carretera and :NEW.orden_carretera = incidente.orden_carretera;
	
		IF (nIncidentes > 3) THEN
			raise_application_error (-20001, 'La etapa: ' || :NEW.num_etapa || ' no puede discurrir por el tramo '
				|| :NEW.orden_carretera || ' '|| :NEW.id_carretera);
		END IF;
	END;
	
	CREATE OR REPLACE TRIGGER "TRIGGER_PLSQL_T1_2" BEFORE INSERT OR UPDATE ON discurre 
	FOR EACH ROW 
	DECLARE
		num number;
	BEGIN
	  SELECT COUNT(*) INTO num FROM incidente i, discurre dato
		WHERE :new.id_carretera = d.id_carretera
		AND :new.orden_carretera = d.orden_carretera_carretera 
		AND :new.num_etapa = d.num_etapa
		AND i.id_carretera = d.id_carretera
		AND i.orden_carretera = d.orden_carretera;
	  IF numincidentes IS NULL THEN numincidentes := 0;
	  END IF;
	  IF num > 3 THEN RAISE_APPLICATION_ERROR(-20001, 'No se puede discurrir por ese tramo');
	  END IF;  
	END;
	
	--TANDA 2:
	--1: se debe mantener actualizada la longitud de las carreteras en base a la longitud de los tramos que la forman
	create or replace TRIGGER "TRIGGER_PLSQL_T2_1" AFTER INSERT OR UPDATE OR DELETE ON TRAMO 
	FOR EACH ROW 
	BEGIN
		IF INSERTING THEN
			update carretera set longitud_carretera = longitud_carretera + :NEW.longitud_tramo 
				where id_carretera = :NEW.id_carretera;

		ELSIF UPDATING THEN
			update carretera set longitud_carretera = longitud_carretera - :OLD.longitud_tramo + :NEW.longitud_tramo 
				where id_carretera = :NEW.id_carretera;

		ELSE
			update carretera set longitud_carretera = longitud_carretera - :OLD.longitud_tramo 
				where id_carretera = :OLD.id_carretera;

		END IF;
	END;
		
	--2: un tramo no puede pasar por un término municipal durante 3km si discurre por más de 3 etapas
	create or replace TRIGGER "TRIGGER_PLSQL_T2_2" BEFORE INSERT OR UPDATE ON PASA 
	FOR EACH ROW 
	DECLARE
		nEtapas number;
		longitud pasa.km_entrada%TYPE;
	BEGIN
		select count(num_etapa) into nEtapas
		from discurre
		where :NEW.orden_carretera=orden_carretera and :NEW.id_carretera=id_carretera;

		longitud := :NEW.km_salida - :NEW.km_entrada;

		IF(nEtapas > 3 AND longitud = 3) THEN
			raise_application_error (-20001, 'El tramo: ' || :NEW.orden_carretera || '  ' || 
				:NEW.id_carretera || 'no puede pasar por el término municipal');
		END IF;
	END;

--PROCEDIMIENTOS:
	--TANDA 1: procedimiento que muestre para cada ciclista su nombre, categoría, número de patrocinadores de su equipo y el número de etapas 
	--de montaña que disputa. Además, han de mostrarse de acuerdo con el formato que viene a continuación, las etapas de montaña que disputa, 
	--así como el número de maillots que lleva en cada una de ellas, junto con el número de tramos de carretera por os que pasa cada etapa. 
	--No deben salir ciclistas que no corran etapas de montaña.
	create or replace PROCEDURE PROCEDURE_PLSQL2017_TANDA1 IS 
		nMaill number;
		nTramos number;
		
		CURSOR ciclistas IS 
			SELECT c.nombre_ciclista, c.categoria_ciclista, COUNT(distinct es.id_patrocinador) AS numpratrocinadores, COUNT(distinct em.num_etapa) numetapasmontaña
			FROM ciclista c, etapamontana em, es_subvencionado es, disputa d
			WHERE c.nombre_equipo = es.nombre_equipo
				AND d.num_etapa = em.num_etapa
				AND c.nombre_ciclista = d.nombre_ciclista
			group by c.nombre_ciclista, c.categoria_ciclista;
			
		CURSOR etapas (n_ciclista ciclista.nombre_ciclista%TYPE) IS
			SELECT em.num_etapa, e.fecha_etapa, em.altitud
			FROM etapa e, etapamontana em, disputa dis
			WHERE n_ciclista = dis.nombre_ciclista AND dis.num_etapa = em.num_etapa 
				AND em.num_etapa = e.num_etapa
			group by em.num_etapa, e.fecha_etapa, em.altitud;
		
	BEGIN
		FOR c IN ciclistas LOOP
			IF c.numetapasmontaña <> 0 THEN
				DBMS_OUTPUT.PUT_LINE('CICLISTA: ' || c.nombre_ciclista || ' ' || c.categoria_ciclista || ' ' || c.numpratrocinadores || ' ' || c.numetapasmontaña );
				FOR e IN etapas(c.nombre_ciclista) LOOP
				
					select NVL(COUNT(d.orden_carretera),0) into nTramos from discurre d where e.num_etapa = d.num_etapa;
					select NVL(COUNT(distinct ll.id_maillot),0) into nMaill FROM lleva ll where e.num_etapa = ll.num_etapa AND c.nombre_ciclista = ll.nombre_ciclista;
					
					DBMS_OUTPUT.PUT_LINE('--------ETAPA:' || e.num_etapa || ' ' || e.fecha_etapa || ' ' || e.altitud || ' ' 
						|| nMaill ||' ' || nTramos);
						
				END LOOP;
			END IF;
		END LOOP;
	END;
	
	--TANDA 2:
	--Crear un procedimiento que muestre para cada patrocinador su nombre, el nombre del término municipal en el que está, el número de tramos 
	--que pasan por dicho término municipal y el número de equipos que patrocina. Además, han de mostrarse de acuerdo con el formato que viene 
	--a continuación, el nombre y número de ciclistas de los equipos y la cantidad que subvenciona a cada uno de ellos.
	--No deben salir patrocinadores que no subvencionen equipos.
	create or replace PROCEDURE PROCEDURE_PLSQL2017_TANDA2 IS
		numEquipos number;
		
		CURSOR patrocinadores IS
			SELECT p.id_patrocinador, p.nombre_patrocinador, tm.nombre_tm, count(pasa.id_tm) AS num_tramos_pasa
			FROM patrocinador p, terminomunicipal tm, pasa
			WHERE p.id_tm = tm.id_tm AND tm.id_tm = pasa.id_tm
			GROUP BY p.id_patrocinador,p.nombre_patrocinador, tm.nombre_tm;
			
		CURSOR equipos (nombre patrocinador.nombre_patrocinador%TYPE) IS
			SELECT es.nombre_equipo, count(c.nombre_ciclista) AS  num_ciclistas, es.cantidad
			FROM patrocinador p, ciclista c, es_subvencionado es
			WHERE nombre = p.nombre_patrocinador AND p.id_patrocinador = es.id_patrocinador
			AND es.nombre_equipo = c.nombre_equipo
			GROUP BY es.nombre_equipo,es.cantidad;
		
	BEGIN
		FOR p IN patrocinadores LOOP
		
			SELECT count(distinct es_subvencionado.nombre_equipo) into numEquipos FROM es_subvencionado WHERE p.id_patrocinador = es_subvencionado.id_patrocinador;
			IF numEquipos <> 0 THEN
			
				DBMS_OUTPUT.PUT_LINE('PATROCINADOR: ' || p.nombre_patrocinador || ' ' || p.nombre_tm || ' ' || p.num_tramos_pasa || ' ' || numEquipos );
				FOR e IN equipos(p.nombre_patrocinador) LOOP
					DBMS_OUTPUT.PUT_LINE('-----EQUIPO: ' || e.nombre_equipo || ' ' || e.num_ciclistas || ' ' || e.cantidad );
				END LOOP;
			END IF;
		END LOOP;		
	END;
	
--FUNCIONES:
	--TANDA 1:
	--Crea una función que dado un número de patrocinadores np (probad con np=1) devuelva el tramo de carretera, con id_carretera más bajo, 
	--que pasa por mayor número de términos municipales en los que estén más de np patrocinadores. Se debe devolver también el número 
	--de términos municipales.
	create or replace FUNCTION FUNCTION_PLSQL2017_TANDA1 (
	  NUMPATROCINADOR IN VARCHAR2 
	, ORDENCARRETERA OUT TRAMO.ORDEN_CARRETERA%TYPE 
	, IDCARRETERA OUT TRAMO.ID_CARRETERA%TYPE
	, NUMTERMINOSMUN OUT NUMBER
	) RETURN NUMBER AS 

	ordenCarreteras TRAMO.orden_carretera%TYPE;
	idCarreteras TRAMO.id_carretera%TYPE;

	BEGIN
		select orden_carretera,id_carretera,numero into ORDENCARRETERA,IDCARRETERA,NUMTERMINOSMUN
		from (select orden_carretera,id_carretera,count(id_tm) numero
		from pasa
		where id_tm IN (select id_tm from patrocinador group by id_tm having count(id_patrocinador)>NUMPATROCINADOR)
		group by orden_carretera,id_carretera
		having count(id_tm) = (select DISTINCT max(count(id_tm))
		
		from pasa
		where id_tm IN (select id_tm from patrocinador group by id_tm having count(id_patrocinador)>NUMPATROCINADOR)
		group by orden_carretera,id_carretera)
		order by id_carretera)
		where rownum < 2;
		
		return IDCARRETERA;
	END FUNCTION_PLSQL2017_TANDA1;
	
	DECLARE
	  NUMPATROCINADOR VARCHAR2(200);
	  ORDENCARRETERA NUMBER;
	  IDCARRETERA CHAR(4);
	  NUMTERMINOSMUN NUMBER;
	  v_Return NUMBER;
	BEGIN
	  NUMPATROCINADOR := NULL;
	  v_Return := EJERCICIO3(
		NUMPATROCINADOR => NUMPATROCINADOR,
		ORDENCARRETERA => ORDENCARRETERA,
		IDCARRETERA => IDCARRETERA,
		NUMTERMINOSMUN => NUMTERMINOSMUN
	  );
	  :v_Return := v_Return;
		DBMS_OUTPUT.PUT_LINE('ORDENCARRETERA = ' || ORDENCARRETERA);
	  :ORDENCARRETERA := ORDENCARRETERA; 
		DBMS_OUTPUT.PUT_LINE('IDCARRETERA = ' || IDCARRETERA); 
	  :IDCARRETERA := IDCARRETERA; 
		DBMS_OUTPUT.PUT_LINE('NUMTERMINOSMUN = ' || NUMTERMINOSMUN);
	  :NUMTERMINOSMUN := NUMTERMINOSMUN;
	END;
	
	--TANDA 2:
	--Crea una función que dado un número de parejas np (probad con np=1) devuelva el tramo de carretera, con id_carretera más bajo, 
	--donde ocurre mayor número de incidentes a los que acuden más de np parejas. Se debe devolver también el número de incidente.
	create or replace FUNCTION FUNCTION_PLSQL2017_TANDA2 (
	  NUMPAREJAS IN VARCHAR2 
	, ORDENCARRETERA OUT TRAMO.ORDEN_CARRETERA%TYPE 
	, IDCARRETERA OUT TRAMO.ID_CARRETERA%TYPE
	, NUMINCIDENTES OUT NUMBER
	) RETURN NUMBER AS 

	ordenCarreteras TRAMO.orden_carretera%TYPE;
	idCarreteras TRAMO.id_carretera%TYPE;

	BEGIN
		select orden_carretera,id_carretera,numero into ORDENCARRETERA,IDCARRETERA,NUMINCIDENTES
		from (select orden_carretera,id_carretera,count(id_incidente) numero
		from incidente
		where id_incidente IN (select id_incidente from acude group by id_incidente having count(licencia1)>NUMPAREJAS)
		group by orden_carretera,id_carretera
		having count(id_incidente) = (select DISTINCT max(count(id_incidente))
		from incidente
		where id_incidente IN (select id_incidente from acude group by id_incidente having count(licencia1)>NUMPAREJAS)
		group by orden_carretera,id_carretera)
		order by id_carretera)
		where rownum < 2;
		
		return IDCARRETERA;
	END FUNCTION_PLSQL2017_TANDA2;
	
	DECLARE
	  NUMPAREJAS VARCHAR2(200);
	  ORDENCARRETERA NUMBER;
	  IDCARRETERA CHAR(4);
	  NUMINCIDENTES NUMBER;
	  v_Return NUMBER;
	BEGIN
	  NUMPAREJAS := NULL;

	  v_Return := FUNCTION_PLSQL2017_TANDA1(
		NUMPAREJAS => NUMPAREJAS,
		ORDENCARRETERA => ORDENCARRETERA,
		IDCARRETERA => IDCARRETERA,
		NUMINCIDENTES => NUMINCIDENTES
	  );
	  :v_Return := v_Return;
		DBMS_OUTPUT.PUT_LINE('ORDENCARRETERA = ' || ORDENCARRETERA);
	  :ORDENCARRETERA := ORDENCARRETERA;
		DBMS_OUTPUT.PUT_LINE('IDCARRETERA = ' || IDCARRETERA);
	  :IDCARRETERA := IDCARRETERA;
		DBMS_OUTPUT.PUT_LINE('NUMINCIDENTES = ' || NUMINCIDENTES);
	  :NUMINCIDENTES := NUMINCIDENTES; 
	END;
	