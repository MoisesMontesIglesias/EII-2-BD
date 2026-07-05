--EJ 1.1:
	create or replace TRIGGER TRIGGER1 
	BEFORE INSERT OR UPDATE ON ES_SUBVENCIONADO 
	FOR EACH ROW 
	DECLARE
		presupEquipo equipo.presupuesto%TYPE;
		numCiclistas number;
		porcentaje es_subvencionado.cantidad%TYPE;
	BEGIN
		select e.presupuesto into presupEquipo
		from equipo e
		where e.nombre_equipo = :NEW.nombre_equipo;
		
		select count(c.nombre_ciclista) into numCiclistas
		from ciclista c
		where c.nombre_equipo = :NEW.nombre_equipo;
		
		IF(numCiclistas < 5) THEN
			porcentaje := presupEquipo * 0.1;
			IF(:NEW.cantidad > porcentaje) THEN
				RAISE_APPLICATION_ERROR(-20001, 'La cantidad subvencionada supera el 10% del presupuesto');
			END IF;
		ELSE 
			porcentaje := presupEquipo * 0.3;
			IF(:NEW.cantidad > porcentaje) THEN
				RAISE_APPLICATION_ERROR(-20002, 'La cantidad subvencionada supera el 30% del presupuesto');
			END IF;
		END IF;
	END;
	
	create or replace TRIGGER TRIGGER1 
	BEFORE INSERT OR UPDATE ON ES_SUBVENCIONADO 
	FOR EACH ROW 
	DECLARE
		presupEquipo equipo.presupuesto%TYPE;
		numCiclistas number;
		porcentaje es_subvencionado.cantidad%TYPE;
	BEGIN
		select e.presupuesto into presupEquipo
		from equipo e
		where e.nombre_equipo = :NEW.nombre_equipo;
		
		select count(c.nombre_ciclista) into numCiclistas
		from ciclista c
		where c.nombre_equipo = :NEW.nombre_equipo;
		
		IF INSERTING THEN
			IF (:NEW.CANTIDAD / (presupEquipo + :NEW.CANTIDAD) > 0.3 OR (numCiclistas <= 5 AND :NEW.CANTIDAD / (presupEquipo + :NEW.CANTIDAD) > 0.1)) THEN
			  raise_application_error(-20001, 'La cantidad subvencionada supera el porcentaje mínimo del presupuesto');
			ELSE
			  UPDATE EQUIPO SET PRESUPUESTO = PRESUPUESTO + :NEW.CANTIDAD WHERE NOMBRE_EQUIPO=:NEW.NOMBRE_EQUIPO;
			 END IF;
		  ELSE
			IF (:OLD.NOMBRE_EQUIPO = :NEW.NOMBRE_EQUIPO) THEN
			  IF (:NEW.CANTIDAD / (presupEquipo - :OLD.CANTIDAD + :NEW.CANTIDAD) > 0.3 OR (numCiclistas <= 5 AND :NEW.CANTIDAD / (presupEquipo -:OLD.CANTIDAD + :NEW.CANTIDAD) > 0.1)) THEN
			  raise_application_error(-20002, 'La cantidad subvencionada supera el porcentaje mínimo del presupuesto');
			ELSE
			  UPDATE EQUIPO SET PRESUPUESTO = PRESUPUESTO -:OLD.CANTIDAD + :NEW.CANTIDAD WHERE NOMBRE_EQUIPO=:NEW.NOMBRE_EQUIPO;
			 END IF;
		  END IF;
		END IF;
	END;

--EJ 1.2:
	create or replace TRIGGER TRIGGER2 
	BEFORE INSERT OR UPDATE ON LLEVA 
	FOR EACH ROW 
	DECLARE
		nEtapasPrimeraPos number;
		id_maill maillot.id_maillot%TYPE;
	BEGIN
		select count(d.orden_clasificacion) into nEtapasPrimeraPos
		from disputa d
		where d.nombre_ciclista = :NEW.nombre_ciclista
			and d.num_etapa in (select num_etapa from etapamontana)
			and d.orden_clasificacion = '1';
		
		select id_maillot into id_maill from maillot where color = 'azul';
		
		IF (:NEW.id_maillot = id_maill and nEtapasPrimeraPos <1) THEN
			RAISE_APPLICATION_ERROR(-20003, 'El ciclista no ha ganado ninguna etapa de montaña');
		END IF;
	END;

	
--EJ 2:
create or replace PROCEDURE PROCEDURE_EJ2 AS 
    ntram number;
    ncarr number;
    nciclist number;
    netp number;
    nincid number;
	
    CURSOR ciclist (t ciclista.tipo_ciclista%TYPE) IS
        SELECT distinct nombre_ciclista 
		from ciclista
		where t = tipo_ciclista;

    CURSOR tciclist IS
        SELECT distinct ciclista.tipo_ciclista
        FROM ciclista;
    
    CURSOR etp(nmbr ciclista.nombre_ciclista%TYPE) IS
        SELECT num_etapa
        FROM disputa
        WHERE orden_clasificacion = '1' and nombre_ciclista = nmbr;

BEGIN
    for tCiclista in tciclist loop
	    select count(distinct disputa.num_etapa) into netp 
        from disputa, ciclista
        where disputa.nombre_ciclista = ciclista.nombre_ciclista 
            and tCiclista.tipo_ciclista = ciclista.tipo_ciclista 
            and disputa.orden_clasificacion = 1;
		
        select count(distinct nombre_ciclista) into nciclist 
        from ciclista 
        where tCiclista.tipo_ciclista = tipo_ciclista;

        if netp > 0 THEN
            DBMS_OUTPUT.PUT_LINE('TIPO CICLISTA: ' || tCiclista.tipo_ciclista || ' ' || nciclist || ' ' || netp );
            for c in ciclist(tCiclista.tipo_ciclista) loop
                for e in etp(c.nombre_ciclista) loop
                    select count(distinct id_carretera) into ncarr from discurre where num_etapa = e.num_etapa;
                    select count(*) into ntram from discurre d where d.num_etapa = e.num_etapa;
                    DBMS_OUTPUT.PUT_LINE('---ETAPA GANAD: ' || e.num_etapa || ' ' || ntram || ' ' || ncarr || ' ' || nincid );
                end loop;
            end loop;
        end if;
    end loop;
    
END PROCEDURE_EJ2;

--EJ 3:
CREATE OR REPLACE FUNCTION FUNCTION1 
(id_tm IN terminomunicipal.id_tm%TYPE) RETURN NUMBER AS numero NUMBER :=0;
BEGIN
    select d.num_etapa into numero
    from etapa e, incidente i,pasa p,disputa d,discurre dis, tramo t
    where e.num_etapa=dis.num_etapa 
        and d.num_etapa=e.num_etapa 
        and dis.orden_carretera=i.orden_carretera 
        and dis.id_carretera=i.id_carretera 
        and p.id_carretera=dis.id_carretera 
        and dis.orden_carretera=p.orden_carretera 
        and (t.id_carretera,t.orden_carretera) NOT IN(select i.id_carretera,i.orden_carretera from incidente i,tramo t where t.id_carretera=i.id_carretera and i.orden_carretera=t.orden_carretera)
        and rownum < 2;
    
    return numero;
    
END FUNCTION1;
