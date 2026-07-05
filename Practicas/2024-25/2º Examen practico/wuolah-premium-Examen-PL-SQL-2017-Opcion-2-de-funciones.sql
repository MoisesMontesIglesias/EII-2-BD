--FUNCIÓN TANDA 1:
	--Crea una función que dado un número de patrocinadores np (probad con np=1) devuelva el tramo de carretera, con id_carretera más bajo, 
	--que pasa por mayor número de términos municipales en los que estén más de np patrocinadores. Se debe devolver también el número 
	--de términos municipales.
	create or replace FUNCTION ejercicio3(np in number, numterminos out number) 
	RETURN tramo%ROWTYPE
	AS
		maximonumterm number;
		numterm number;
		aux number;
		ide tramo.id_carretera%TYPE;
		orden tramo.orden_carretera%TYPE;
		longitud tramo.longitud_tramo%TYPE;
		nombre_a tramo.nombre_area%TYPE;
		CURSOR tramos IS select * from pasa;
		devolver tramo%ROWTYPE;
	BEGIN
		maximonumterm:=0;
		FOR tramo IN tramos LOOP
			numterm:=0;
			FOR termino IN (SELECT id_tm from patrocinador p
				GROUP BY id_tm having count(id_patrocinador) > np) LOOP
					SELECT count(*) into aux FROM pasa
						WHERE id_carretera=tramo.id_carretera  
						and orden_carretera=tramo.orden_carretera
						and id_tm=termino.id_tm;
						
					if aux>0 then numterm:=numterm+1;
					end if;
					end loop;
			if numterm = maximonumterm then
				if tramo.id_carretera < ide then
					ide:=tramo.id_carretera;
					orden:=tramo.orden_carretera;
				end if;
			elsif numterm > maximonumterm then
					maximonumterm := numterm;
					ide := tramo.id_carretera;
					orden := tramo.orden_carretera;
			end if;
		end loop;
		numterminos:= numterm;
		select * into devolver from tramo where orden_carretera = orden and id_carretera = ide;
		RETURN devolver;
	END;
	
	
	DECLARE
	  resultado tramo%ROWTYPE;
	  numterm number;
	BEGIN
	  resultado := ejercicio3(1, numterm);
	  DBMS_OUTPUT.PUT_LINE('Numero de terminos: ' || numterm);
	  DBMS_OUTPUT.PUT_LINE('id_carretera: ' || resultado.id_carretera);
	  DBMS_OUTPUT.PUT_LINE('orden_carretera: ' || resultado.orden_carretera);
	  DBMS_OUTPUT.PUT_LINE('longitud_carretera: ' || resultado.longitud_tramo);
	  DBMS_OUTPUT.PUT_LINE('nombre_area: ' || resultado.nombre_area);
	END;