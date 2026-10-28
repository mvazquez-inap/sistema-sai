// Sniffer based on http://www.mozilla.org/docs/web-developer/sniffer/browser_type.html
var uagent    = navigator.userAgent.toLowerCase();
var is_safari = ( (uagent.indexOf('safari') != -1) || (navigator.vendor == "Apple Computer, Inc.") );
var is_ie     = ( (uagent.indexOf('msie') != -1) && (!is_opera) && (!is_safari) && (!is_webtv) );
var is_ie4    = ( (is_ie) && (uagent.indexOf("msie 4.") != -1) );
var is_moz    = (navigator.product == 'Gecko');
var is_ns     = ( (uagent.indexOf('compatible') == -1) && (uagent.indexOf('mozilla') != -1) && (!is_opera) && (!is_webtv) && (!is_safari) );
var is_ns4    = ( (is_ns) && (parseInt(navigator.appVersion) == 4) );
var is_opera  = (uagent.indexOf('opera') != -1);
var is_kon    = (uagent.indexOf('konqueror') != -1);
var is_webtv  = (uagent.indexOf('webtv') != -1);

var is_win    =  ( (uagent.indexOf("win") != -1) || (uagent.indexOf("16bit") !=- 1) );
var is_mac    = ( (uagent.indexOf("mac") != -1) || (navigator.vendor == "Apple Computer, Inc.") );
var ua_vers   = parseInt(navigator.appVersion);
//----------------------------------------------------------------------------------------- 
function GoToURL() {
  var i, args=arguments; 
  document.ReturnValue = false;
  for (i=0; i<(args.length-1); i+=2) eval(args[i]+".location='"+args[i+1]+"'");
}
//----------------------------------------------------------------------------------------- 
// Buscar un índice en un array
function BuscarIndiceArray(ArrayBusqueda,DatoaBuscar,PosicionInicialBusq,LongitudBusq)
{
//  OJO - Falta terminar el substr con LongitudBusq	
	var indice=0;
//	alert("2 - array /" + ArrayBusqueda + "/ - dato /" + DatoaBuscar + "/ - posicion /" + PosicionInicialBusq + "/");
	for(elemento in ArrayBusqueda)
	{
		//alert("3 /" + (ArrayBusqueda[elemento].substr(PosicionInicialBusq)) + "/");
		if((ArrayBusqueda[elemento].substr(PosicionInicialBusq))==DatoaBuscar)
			return indice;

	indice++;
	}

	return -1;
}

//----------------------------------------------------------------------------------------- 
function ValidarFecha(caja)
{ 
   if (caja)
   {  
      var borrar = caja;
      if ((caja.substr(2,1) == "/") && (caja.substr(5,1) == "/"))
      {      
         for (var i=0; i<10; i++)
	     {	
            if (((caja.substr(i,1)<"0") || (caja.substr(i,1)>"9")) && (i != 2) && (i != 5))
			{
               borrar = '';
               break;  
			}  
         }
	     if (borrar)
	     { 
	        var a = caja.substr(6,4);
	        var c = caja.substr(6,2);
		    var m = caja.substr(3,2);
		    var d = caja.substr(0,2);
		    if((a < 1900) || (a > 2050) || (m < 1) || (m > 12) || (d < 1) || (d > 31))
		       borrar = '';
		    else
		    {
		       if(((a%4 != 0) || ((caja.substr(8,2)=='00') && (c%4 != 0))) && (m == 2) && (d > 28))	   
		          borrar = ''; // Año no bisiesto y es febrero y el dia es mayor a 28
			   else	
			   {
		          if ((((m == 4) || (m == 6) || (m == 9) || (m==11)) && (d>30)) || ((m==2) && (d>29)))
			         borrar = '';	      				  	 
			   }  // else
		    } // fin else
         } // if (error)
      } // if ((caja.substr(2,1) == "/") && (caja.substr(5,1) == "/"))			    			
	  else
	     borrar = '';
	  if (borrar == '')
	     return false;
	 else
	 	 return true;
   } // if (caja)  
   return false;
} // FUNCION

//----------------------------------------------------------------------------------------- 
// Verifica que la Fecha Actual sea mayor a FechaInferior y menor/igual a FechaSuperior
// Formatos Fecha: dd/mm/aaaa
function FechasOrdenadas(FechaInferior,FechaActual,FechaSuperior)
{
	var FIDia=FechaInferior.substr(0,2);
	var FIMes=FechaInferior.substr(3,2);
	var FIAnio=FechaInferior.substr(6,4);
	var FADia=FechaActual.substr(0,2);
	var FAMes=FechaActual.substr(3,2);
	var FAAnio=FechaActual.substr(6,4);
	var FSDia=FechaSuperior.substr(0,2);
	var FSMes=FechaSuperior.substr(3,2);
	var FSAnio=FechaSuperior.substr(6,4);
	//alert(FIDia + "/" + FIMes + "/" + FIAnio + " " + FADia + "/" + FAMes + "/" + FAAnio + " " + FSDia + "/" + FSMes + "/" + FSAnio);
	
	if(FAAnio<FIAnio)
		return false;
	else if(FAAnio==FIAnio && FAMes<FIMes)
		return false;
	else if(FAAnio==FIAnio && FAMes==FIMes && FADia<FIDia)
		return false;
	else if(FAAnio>FSAnio)
		return false;
	else if(FAAnio==FSAnio && FAMes>FSMes)
		return false;
	else if(FAAnio==FSAnio && FAMes==FSMes && FADia>FSDia)
		return false;
	else
		return true;
}
//----------------------------------------------------------------------------------------- 
// Verifica que la CantActual sea mayor/igual a CantInferior y menor/igual a CantSuperior
// Depende del parámetro Orden
// Las cantidades deben tener punto en vez de coma decimal
function CantOrdenadas(CantInferior,CantActual,CantSuperior,Orden)
{
//	alert("cantordenadasdjs -" + CantInferior + "-" + CantActual + "-" + CantSuperior);
	if(Orden=='C')
	{
		if(CantActual<CantInferior || CantActual>CantSuperior)
			return false;
	}
	else if(Orden=='D')
	{
		if(CantActual>CantInferior || CantActual<CantSuperior)
			return false;
	}
	return true;
}

//----------------------------------------------------------------------------------------- 
function HorasOrdenadas(hora1,hora2)
{
	var H1=hora1.substr(0,2);
	var M1=hora1.substr(3,2);
	var H2=hora2.substr(0,2);
	var M2=hora2.substr(3,2);
	
	if(H2<H1)
		return false;
	else if(H1==H2 && M2<M1)
		return false;
	else
		return true;
}
//----------------------------------------------------------------------------------------- 
// Convierte la coma en punto
// Convierte lo ingresado en un número
function ConvertirPunto (s)
{
  var texto="";
  var i;

  s=String(s);

  for (i = 0; i < s.length; i++)
  {
	 var c = s.charAt(i);	 
	 if(c==",")
		 	texto=texto+".";
	 else
	 		texto=texto+c;
  }
  return parseFloat(texto);
}
//-----------------------------------------------------------------------------------------
// Convierte el punto en coma
function ConvertirComa (s)
{
  var texto="";
  var i;

  s=String(s);

  for (i = 0; i < s.length; i++)
  {
	 var c = s.charAt(i);	 
	 if(c==".")
		 	texto=texto+",";
	 else
	 		texto=texto+c;
  }
  return texto;
}
//----------------------------------------------------------------------------------------- 
function ConvertirFecha(campoaconvertir,formatoinput,formatooutput)
{
	
	var campodevuelto=campoaconvertir;
 
	if(campoaconvertir=='')
		campodevuelto="";
	else if(formatoinput=='aaaamm' && formatooutput=='mm/aaaa')
		campodevuelto=campoaconvertir.substr(4,2)+campoaconvertir.substr(0,4);
	else if(formatoinput=='mm/aaaa' && formatooutput=='aaaamm')
		campodevuelto=campoaconvertir.substr(3,4)+campoaconvertir.substr(0,2);
	else if(formatoinput=='nn/aaaa' && formatooutput=='aaaann')
		campodevuelto=campoaconvertir.substr(3,4)+campoaconvertir.substr(0,2);
	else if(formatoinput=='dd/mm/aaaa' && formatooutput=='aaaammdd')
		campodevuelto=campoaconvertir.substr(6,4)+campoaconvertir.substr(3,2)+campoaconvertir.substr(0,2);
	else if(formatoinput=='aaaa-mm-dd' && formatooutput=='aaaammdd')
		campodevuelto=campoaconvertir.substr(0,4)+campoaconvertir.substr(5,2)+campoaconvertir.substr(8,2);

	return campodevuelto;
}
//----------------------------------------------------------------------------------------- 
function Popup(popup_url,name,ancho,alto,varx,vary,barras) {
window.focus(name);
var tmp = window.open(popup_url,name,'menubar=no,location=no,toolbar=no,status=no,scrollbars=' + barras +',directories=no,width=' + ancho + ',height=' + alto);
tmp.moveTo(varx,vary);
tmp.window.focus();
}
//----------------------------------------------------------------------------------------- 
function EncontrarObjeto(n, d) { 
  var p,i,x;  if(!d) d=document; if((p=n.indexOf("?"))>0&&parent.frames.length) {
    d=parent.frames[n.substring(p+1)].document; n=n.substring(0,p);}
  if(!(x=d[n])&&d.all) x=d.all[n]; for (i=0;!x&&i<d.forms.length;i++) x=d.forms[i][n];
  for(i=0;!x&&d.layers&&i<d.layers.length;i++) x=EncontrarObjeto(n,d.layers[i].document);
  if(!x && d.getElementById) x=d.getElementById(n); return x;
}
//----------------------------------------------------------------------------------------- 
function CambiarPropiedad(objName,x,theProp,theValue) {
 	
  var obj = EncontrarObjeto(objName);
  /*
  alert('objName='+objName);
  alert('obj='+obj);
  alert('x='+x);
  alert('theProp='+theProp);
  alert('theValue='+theValue); 
  */
  if (obj && (theProp.indexOf("style.")==-1 || obj.style)){
    if (theValue == true || theValue == false)
      eval("obj."+theProp+"="+theValue);
    else eval("obj."+theProp+"='"+theValue+"'");
  }
}
//----------------------------------------------------------------------------------------- 
function SetearTexto(objName,newText,d) 
{ //v4.01
  var obj;
  
  if(!d) d=document;
  
  if ((obj=EncontrarObjeto(objName,d))!=null)
  {
	 if (d.layers) 
	  {
		
		 d.write(unescape(newText)); d.close();
	  }
      else 
		 if ((obj.type=="textarea") || (obj.type=="text"))
		 	obj.value=newText;
			
		 else
		 obj.innerHTML = unescape(newText);
		
  }

/*  if ((obj=EncontrarObjeto(objName))!=null) with (obj)
    if (document.layers) {document.write(unescape(newText)); document.close();}
    else innerHTML = unescape(newText);*/
}
//----------------------------------------------------------------------------------------- 
function addValorPopupTipo(docu, idTextbox, codigo, nombrecontenido, tipoorg_codigo, tipoorg_contenido, idtextocontenido){
	var elSelect = docu.getElementById(idTextbox);
	elSelect.value=codigo;
	SetearTexto(idtextocontenido,nombrecontenido,docu);

	var elSelect2 = docu.getElementById(tipoorg_codigo);
	elSelect2.value=tipoorg_contenido;
}
//----------------------------------------------------------------------------------------- 
function addValorPopup(docu, idTextbox, codigo, nombrecontenido, idtextocontenido){
	var elSelect = docu.getElementById(idTextbox);
	elSelect.value=codigo;
	SetearTexto(idtextocontenido,nombrecontenido,docu);
}
//----------------------------------------------------------------------------------------- 
function CompletarString(texto,largo,caracter)
{
	var nuevotexto=texto;
	
	for(i=texto.length+1;i<=largo;i++)
		nuevotexto=nuevotexto+caracter;
	
	return nuevotexto
}

//----------------------------------------------------------------------------------------- 
function ValidarContenido(campo,tipovalidacion)
{
	var rexp;
	
 if(campo.substr(0,1)==" ")
 	return false;
 
 switch(tipovalidacion)
 {
	case "AlfanumericoPuro": // campo alfanumerico sin caracteres especiales
		rexp = /[^A-Za-z0-9]/; 
		if(rexp.test(campo)) 
			return false;
 		break;
	case "AlfabeticoPuro": // campo alfabetico con caracteres especiales
		rexp = /[^A-Za-zÁÉÍÓÚÄËÏÖÜÑñáéíóúäëïöüàèìòùâêîôûÇç ']/; 
		if(rexp.test(campo)) 
			return false;
 		break;		
	case "Email": // campo alfanumerico con algunos caracteres especiales (emails)
//		rexp = new RegExp("^[-\._a-z0-9]+@([a-z0-9]+[\.]{1}){1,2}[a-z]{2,4}([\.]{1}[a-z]{2}){0,1}$","gi");
		rexp = new RegExp("^[-\._a-z0-9]+@([-_a-z0-9]+[\.]{1}){1,2}[a-z]{2,4}([\.]{1}[a-z]{2}){0,1}$","gi");

		if(!rexp.test(campo)) 
			return false;
 		break;
	case "Hexa6Digitos": // color de semáforos
		rexp = new RegExp("^[0-9A-F]{6}$","gi");
		if(!rexp.test(campo)) 
			return false;
		break;
	case "Jurisdiccion": // campo numerico con puntos (sólo para Jurisdicciones)
		rexp = /^[0-9]{2}\.([0-9]{3}\.([0-9a-zA-Z ]{2}\.){0,7}){0,1}$/; 
		if(!rexp.test(campo)) 
			return false;
 		break;
	case "NumericoEntero": // campo numerico entero
		rexp = /[^0-9]/; 
		if(rexp.test(campo)) 
			return false;
		break;
	case "Numerico2Decimales": // campo numerico con 2 decimales maximo
		rexp = new RegExp("^[0-9]+(,[0-9]{1,2}){0,1}$","gi");
		if(!rexp.test(campo)) 
			return false;
		break;
	case "Periodo": // campo MM/AAAA
		rexp = new RegExp("^[0-9]{2}/[0-9]{4}$","gi");
		if(!rexp.test(campo)) 
			return false;

		anio = campo.substr(3,4);
		mes = campo.substr(0,2);
		if((anio < 2000) || (anio > 2050) || (mes < 1) || (mes > 12))
		   return false;
			
		break;	

	case "Hora24": // campo HH:MM
		rexp = new RegExp("^[0-9]{2}:[0-9]{2}$","gi");
		if(!rexp.test(campo)) 
			return false;

		var hora = campo.substr(0,2);
		var minuto = campo.substr(3,2);
		if((hora < 0) || (hora > 23) || (minuto < 0) || (minuto > 59))
		   return false;
			
		break;	
	
	case "CUIT": // 11 posiciones numericas con digito mod.11 

			// Para desarrollo
			//	return true;
	
			if(campo.substr(0,11)=="00000000000")
					return false;
				
				rexp = new RegExp("^[0-9]{11}$","gi");
				
				if(!rexp.test(campo)) 
					return false;
					
				var array_factor_peso = new Array(5,4,3,2,7,6,5,4,3,2);
				var suma=0;
				var resto,digito_verificador;
			
				for (i=0; i<=9; i++)  
					suma=suma+campo.substr(i,1)*array_factor_peso[i]; 	
			
				resto=suma%11;
				digito_verificador=11-resto;
				
				if (digito_verificador == 11)
					digito_verificador = 0;
			
				if (digito_verificador==campo.substr(10,1)) 
					return true; 
				else 
					return false;
		
		break;
			
 	default:
		alert(" Validación no definida - Avise a su administrador");
 		return false;
 		break;
 }
 return true;
}

//----------------------------------------------------------------------------------------- 
function ValidarPassword(clave,claveactual,identificacion,longmin)
{
//	var message="Error: Ingrese una nueva clave";
	var i = 0;
	var p = 0; // codigo de error que se produjo
	var c3 = 1; // cantidad de letras iguales secuenciales
	var a = 0; // mantiene el codigo ascii al recorrer la clave para las validaciones
	var sa = 1; // cantidad de letras consecutivas segun abecedario
	var sd = 1; // cantidad de letras consecutivas segun abecedario inverso
	var pa = 0; // mantiene la cantidad de caracteres iguales entre la nueva clave y la clave actual
	var ca = 0; // cuenta la cantidad de letras
	var cn = 0; // cuenta la cantidad de numeros
	var ant = 0; // mantiene un registro de la letra anterior
	var layout = new Array(); // array que contiene secuencia de caracteres comunes

	layout[layout.length] = "QWERTY";
	layout[layout.length] = "YTREWQ";
	layout[layout.length] = "ASDFG";
	layout[layout.length] = "GFDSA";
	layout[layout.length] = "ZXCVB";
	layout[layout.length] = "BVCXZ";

	if (clave.length<longmin)
		p=12;

	var UsrId = identificacion.charAt(identificacion.length -1); // contiene la identificacion al reves
	for (i = identificacion.length - 2; i >= 0; i--)
		UsrId += identificacion.charAt(i);

	// Verifica si la clave contiene a la identificacion (al derecho y al reves)
	if ((clave.indexOf(identificacion) != -1) || (identificacion.indexOf(clave) != -1))
		p = 9;
	else
		if ((clave.indexOf(UsrId) != -1) || (UsrId.indexOf(clave) != -1))
			p = 10;

	// Verifica si la clave contiene una secuencia de caracteres comunes
	if (p == 0)
	{
		for (i = 0; i < layout.length; i++)
		{
			if ((clave.toUpperCase().indexOf(layout[i]) != -1))
			{
				p = 6;
				break;
			}
		}
	}

	if (p == 0)
	{
		for (i = 0; i < clave.length; i++)
		{
			a = clave.charCodeAt(i);
			if (a >= 48 && a <= 57)
				cn++;
			else
				if ((a >= 65 && a <= 90) || (a >= 97 && a <= 122))
					ca++;

			if (a == ant)
			{
				if (++c3 > 3) // si tengo mas de 3 letras iguales consecutivas
				{
					p = 2;
					break;
				}
			}
			else
			{
				c3 = 1;
				if (ant == a - 1)
				{
					if (++sa > 3) // mas de 3 letras consecutivas segun abecedario
					{
						p = 4;
						break;
					}
					sd = 1;
				}
				else
				{
					if (ant == a + 1)
					{
						if (++sd > 3) // mas de 3 letras consecutivas segun abecedario inverso
						{
							p = 5;
							break;
						}
						sa = 1;
					}
					else
					{
						sa = 1;
						sd = 1;
					}
				}
			}

			if (a == claveactual.charCodeAt(i))
			{
				if (++pa > 5) // si tiene mas de 5 caracteres iguales que la clave actual
				{
					p = 14;
					break;
				}
			}

			ant = a;

		}
	}

	if (p == 0 && (ca + cn) != clave.length) // si la cantidad de letras y numeros es distinta al largo total, entonces hay caracteres especiales
		p = 11;

	if (p != 0)
		return false;
	else
		return true;
}
//----------------------------------------------------------------------------------------- 
function trim(s) {
  while (s.substring(0,1) == ' ') {
    s = s.substring(1,s.length);
  }
  while (s.substring(s.length-1,s.length) == ' ') {
    s = s.substring(0,s.length-1);
  }
  return s;
}
//----------------------------------------------------------------------------------------- 
function Convertirperiodo(periodo,formatoinput,formatooutput)
{
	if(periodo=='') return "";
	
	if(formatoinput=='mm/aaaa' && formatooutput=='aaaamm')
		return periodo.substr(3,4)+periodo.substr(0,2);
	elseif($formatoinput=='aaaamm' && $formatooutput=='mm/aaaa')
		return periodo.substr(4,2)+periodo.substr(0,4);
}
//----------------------------------------------------------------------------------------- 
function PasarItemListaMultiple (ListaOrigen,ListaDestino,Eliminar)
{
	
	var opt;
	var arreglo=new Array();
	var doc;
	var i, j=0;
	for(i=0;i<ListaOrigen.length;i++)
	{
		if (ListaOrigen.options[i].selected==true)
		{	
			doc = ListaOrigen.options[i].ownerDocument;
			if (!doc)
				doc = ListaOrigen.document;
			opt = doc.createElement('OPTION');
			opt.value= ListaOrigen.options[i].value;
			opt.text = ListaOrigen.options[i].text;
			ListaDestino.options.add(opt);
			arreglo[j]=i;
			j++;
		}
	}
	if (Eliminar)
		if (arreglo.length>0)
		{	
			for (i=0;i<arreglo.length;i++)
				ListaOrigen.remove(arreglo[i]-i);
		}
}

//----------------------------------------------------------------------------------------- 
function PasarItemLista(ListaOrigen,ListaDestino,Eliminar)
{
	if(ListaOrigen.selectedIndex!=-1)
	{
		var doc = ListaOrigen.ownerDocument;
		if (!doc)
			doc = ListaOrigen.document;
		var opt = doc.createElement('OPTION');
		opt.value = ListaOrigen.options[ListaOrigen.selectedIndex].value;
		opt.text = ListaOrigen.options[ListaOrigen.selectedIndex].text;
		ListaDestino.options.add(opt);

		if(Eliminar)
			ListaOrigen.remove(ListaOrigen.selectedIndex);
	}
	else
		alert("No hay ningún item seleccionado");
}
//----------------------------------------------------------------------------------------- 
function PasarTodosItemsLista(formulario,ListaOrigen,ListaDestino)
{
	while(ListaOrigen.length>0)
	{
		var doc = ListaOrigen.ownerDocument;
		if (!doc)
			doc = ListaOrigen.document;
		var opt = doc.createElement('OPTION');
		opt.value = ListaOrigen.options[0].value;
		opt.text = ListaOrigen.options[0].text;
		ListaDestino.options.add(opt);
		ListaOrigen.remove(0);
	}
}
//----------------------------------------------------------------------------------------- 
function PasarItemsInicialesLista(formulario,ListaOrigen,ListaDestino,ItemsIniciales) {

	var dato;
	var posListaOrigen;

	for(dato in ItemsIniciales)	{	
		for(posListaOrigen=0;posListaOrigen<ListaOrigen.length;)	{
			if(ItemsIniciales[dato]==ListaOrigen.options[posListaOrigen].value)	{
				ListaOrigen.selectedIndex=posListaOrigen;				
				PasarItemLista(ListaOrigen,ListaDestino,true);
			}
			posListaOrigen++;
		}
	}
}
//----------------------------------------------------------------------------------------- 
function MoverItemLista(Lista,accion)
{
	var valor,texto;
	if(Lista.selectedIndex==-1)
		return false;
		
	switch(accion)
	{
		case "subir":
			if(Lista.selectedIndex>0)
			{
				valor=Lista.options[Lista.selectedIndex-1].value;
				texto=Lista.options[Lista.selectedIndex-1].text;
				Lista.options[Lista.selectedIndex-1].value=Lista.options[Lista.selectedIndex].value;
				Lista.options[Lista.selectedIndex-1].text=Lista.options[Lista.selectedIndex].text;
				Lista.options[Lista.selectedIndex].value=valor;
				Lista.options[Lista.selectedIndex].text=texto;
				Lista.selectedIndex--;
			}
			break;
		case "bajar":
			if(Lista.selectedIndex<Lista.length-1)
			{
				valor=Lista.options[Lista.selectedIndex+1].value;
				texto=Lista.options[Lista.selectedIndex+1].text;
				Lista.options[Lista.selectedIndex+1].value=Lista.options[Lista.selectedIndex].value;
				Lista.options[Lista.selectedIndex+1].text=Lista.options[Lista.selectedIndex].text;
				Lista.options[Lista.selectedIndex].value=valor;
				Lista.options[Lista.selectedIndex].text=texto;
				Lista.selectedIndex++;
			}
			break;
		case "borrar":
			if(Lista.selectedIndex!=-1)
			{
				Lista.remove(Lista.selectedIndex);
			}
			break;
		default:
			return false;
	}
	
	return true;	
}
//----------------------------------------------------------------------------------------- 
function SeleccionarTodosLista(Lista)
{
	var i;
	
	for(i=0;i<Lista.length;i++)
	{
		Lista.options[i].selected=true;
	}
}
//----------------------------------------------------------------------------------------- 
function CargarDatosModificar(accion,formulario,campos_linea,datos,label,textolabel)
{
	var i;

	switch(accion)
	{
		case "CARGAR":
		
	// for(campo in campos_linea) cambio por prototype
		for(campo=0;campo<campos_linea.length;campo++)
		{
				switch(campos_linea[campo].substr(0,3))
				{
					case "hid":
					case "txt":
						
						formulario[campos_linea[campo].substr(4)].value=datos[campo];
						break;
						
					case "cmb":						
						var combo=campos_linea[campo].substr(4);
						for(i=0;i<formulario[combo].length;i++)
						{
							if(formulario[combo].options[i].value==datos[campo]) {
								formulario[combo].selectedIndex=i;
							}
						}
							
						break;
					case "lst":
						var nombreslist=campos_linea[campo].split("|");
						var ListaOrigen=EncontrarObjeto(nombreslist[1]);
						var ListaDestino=EncontrarObjeto(nombreslist[2]);
						PasarTodosItemsLista(formulario,ListaDestino,ListaOrigen);
						PasarItemsInicialesLista(formulario,ListaOrigen,ListaDestino,datos[campo]);
						break;
					case "ls2":
						var dato,posListaOrigen;
						var nombreslist=campos_linea[campo].split("|");
						var encontrado=false,i;
					
						eval("selec_txt_"+nombreslist[1]+".splice(0, selec_txt_"+nombreslist[1]+".length);");
						eval("selec_cod_"+nombreslist[1]+".splice(0, selec_cod_"+nombreslist[1]+".length);");

						for(dato in datos[campo])
						{
							encontrado=false;
							for(i=0;!encontrado && i<eval("txt_todos_"+nombreslist[1]+".length");i++)
							{
								if(eval("cod_todos_"+nombreslist[1]+"["+i+"]")==datos[campo][dato])
								{
									eval("selec_txt_"+nombreslist[1]+"[selec_txt_"+nombreslist[1]+".length] = txt_todos_"+nombreslist[1]+"["+i+"];");
									eval("selec_cod_"+nombreslist[1]+"[selec_cod_"+nombreslist[1]+".length] = cod_todos_"+nombreslist[1]+"["+i+"];");
									encontrado=true;
								}
							}
						}
						ActualizarSelec(nombreslist[1],eval("selec_cod_"+nombreslist[1]),eval("selec_txt_"+nombreslist[1]));						
						
						break;

					case "opt":
						for(i=0;i<formulario[campos_linea[campo].substr(4)].length;i++)
						{
							if(formulario[campos_linea[campo].substr(4)][i].value==datos[campo])
							{
								formulario[campos_linea[campo].substr(4)][i].checked=true;
							}
						}							
						break;
				} // fin switch campo.substr
			} // for campo in campos_linea
			formulario.botonalta.value="Actualizar";
			break;
		case "VACIAR":
//			for(campo in campos_linea) por prototype
			for(campo=0;campo<campos_linea.length;campo++)
			{
				switch(campos_linea[campo].substr(0,3))
				{
					case "hid":
					case "txt":
						formulario[campos_linea[campo].substr(4)].value="";
						break;
					case "cmb":
						formulario[campos_linea[campo].substr(4)].selectedIndex=0;
						break;
					case "lst":
						var nombreslist=campos_linea[campo].split("|");
						var ListaOrigen=EncontrarObjeto(nombreslist[2]);
						var ListaDestino=EncontrarObjeto(nombreslist[1]);

						PasarTodosItemsLista(formulario,ListaOrigen,ListaDestino);
						break;	
					case "ls2":
						var nombreslist=campos_linea[campo].split("|");

						eval("selec_txt_"+nombreslist[1]+".splice(0, selec_txt_"+nombreslist[1]+".length);");
						eval("selec_cod_"+nombreslist[1]+".splice(0, selec_cod_"+nombreslist[1]+".length);");

						ActualizarSelec(nombreslist[1],eval("selec_cod_"+nombreslist[1]),eval("selec_txt_"+nombreslist[1]));						

						break;
					case "opt":
						for(i=0;i<formulario[campos_linea[campo].substr(4)].length;i++)
							formulario[campos_linea[campo].substr(4)][i].checked=false;
						break;
				} // fin switch campo.substr
			} // for campo in campos_linea
			formulario.botonalta.value="Aceptar";
			break;
	}
	
	SetearTexto(label,textolabel);
}
//----------------------------------------------------------------------------------------- 
function ExisteEnArray(ItemsIniciales,ValorABuscar)
{
	for(valor in ItemsIniciales)
		if(ItemsIniciales[valor]==ValorABuscar)
			return true;
	
	return false;
}
//----------------------------------------------------------------------------------------- 
function SeleccionCombo(formulario,campos_linea,datos_grilla,seleccionado)
{
	
	if(seleccionado>0)
	{
		CargarDatosModificar('CARGAR',formulario,campos_linea,datos_grilla[seleccionado],'','');
		formulario.botonalta.value="Actualizar";
		if(formulario.botonbaja)
			formulario.botonbaja.disabled=false;
	}
	else
	{
		CargarDatosModificar('VACIAR',formulario,campos_linea,'','','');
		formulario.botonalta.value="Agregar";
		if(formulario.botonbaja)
			formulario.botonbaja.disabled=true;
	}
}
//----------------------------------------------------------------------------------------- 
function AgregarTagLink(CajaTexto)
{
    var FoundErrors = '';
    var enterURL   = prompt("Indice la URL del sitio", "http://");
    var enterTITLE = prompt("Indique el título del enlace", "");

    if (!enterURL) {
        FoundErrors += " " + "No se ingresó la dirección web.\n";
    }
    if (!enterTITLE) {
        FoundErrors += " " + "No se ingresó el título del enlace.\n";
    }

    if (FoundErrors) {
        alert("Error!\n"+FoundErrors);
        return;
    }
	
	InsertarTexto(CajaTexto,"$$Tipo='Link' URL='"+enterURL+"' Texto='"+enterTITLE+"'$$");

}
//----------------------------------------------------------------------------------------- 
function AgregarEstilo(CajaTexto,estilo,inicio)
{
	switch(estilo)
	{
		case "B":
			if(inicio)
				InsertarTexto(CajaTexto,"$$Tipo='Bold'$$");
			else
				InsertarTexto(CajaTexto,"$$Tipo='BoldFin'$$");
			break;
		case "I":
			if(inicio)
				InsertarTexto(CajaTexto,"$$Tipo='Italic'$$");
			else
				InsertarTexto(CajaTexto,"$$Tipo='ItalicFin'$$");
			break;
		case "U":
			if(inicio)
				InsertarTexto(CajaTexto,"$$Tipo='Underline'$$");
			else
				InsertarTexto(CajaTexto,"$$Tipo='UnderlineFin'$$");
			break;
		case "V":
			InsertarTexto(CajaTexto,"$$Tipo='Bullet'$$");
			break;
	}
}
//----------------------------------------------------------------------------------------- 
function InsertarTexto(CajaTexto,Texto)
{
	// IE
	if ( (ua_vers >= 4) && is_ie && is_win)
	{
		if (CajaTexto.isTextEdit)
		{
			CajaTexto.focus();
			var sel = document.selection;
			var rng = sel.createRange();
			rng.colapse;
			if((sel.type == "Text" || sel.type == "None") && rng != null)
			{
				rng.text = Texto+rng.text;
			}
		}
	}
	//----------------------------------------
	// It's MOZZY!
	//----------------------------------------
	
	else if ( !isNaN(CajaTexto.selectionEnd) )
	{ 
		var ss = CajaTexto.selectionStart;
		var st = CajaTexto.scrollTop;
		var es = CajaTexto.selectionEnd;
		
		if (es <= 2)
		{
			es = CajaTexto.textLength;
		}
		
		var start  = (CajaTexto.value).substring(0, ss);
		var middle = (CajaTexto.value).substring(ss, es);
		var end    = (CajaTexto.value).substring(es, CajaTexto.textLength);
		
		middle = Texto + middle;
		
		CajaTexto.value = start + middle + end;
		
		var cpos = ss + (middle.length);
		
		CajaTexto.selectionStart = cpos;
		CajaTexto.selectionEnd   = cpos;
		CajaTexto.scrollTop      = st;
	}
	//----------------------------------------
	// It's CRAPPY!
	//----------------------------------------
	else
	{
		CajaTexto.value += Texto;
	}
	
	CajaTexto.focus();

	return true;

}
//----------------------------------------------------------------------------------------- 
function Reloj()
	{ 
		
		var Hora = Hoy.getHours() 
		var Minutos = Hoy.getMinutes() 
		var Segundos = Hoy.getSeconds() 
		var dn="AM"
		if (Hora==12) dn="PM" 
		if (Hora>12)
		{
			dn="PM"
			Hora=Hora-12
		}
		if (Hora<=9) Hora = "0" + Hora 
		if (Minutos<=9) Minutos = "0" + Minutos 
		if (Segundos<=9) Segundos = "0" + Segundos 
		var Dia = new Array("Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"); 
		var Mes = new Array("Enero","Febrero","Marzo","Abril","Mayo","Junio","Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"); 

		// Modificamos para que aparezca la fecha completa
		var Mes_Corto = new Array("Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Sep","Oct","Nov","Dic"); 
		var Dia_Corto = new Array("Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"); 

		var Anio = Hoy.getFullYear(); 

		// var Fecha = Dia[Hoy.getDay()] + ", " + Hoy.getDate() + " de " + Mes[Hoy.getMonth()] + " de " + Anio + ", a las "; 
		var Fecha = Dia_Corto[Hoy.getDay()] + ", " + Hoy.getDate() + " " + Mes_Corto[Hoy.getMonth()] + " " + Anio + " "; 


		var Inicio, Script, Final, Total 
		//Inicio = "<font color=#3399CC> "
		//Script = Hora + "&nbsp;:&nbsp;</font>" + Minutos + ":" + Segundos + dn
		//Final = "</b></font>" 
		//Total2 = Inicio + Script + Final 
		if (standardbrowser)
		{
			if (alternate==0)
				Total=Hora+":"+Minutos+" "+dn
			else
				Total=Hora+" "+Minutos+" "+dn
		}else
		{
			if (alternate==0)
				Total=Fecha+" "+Hora+"<span style='color:#E0C2EF'>:</span>"+Minutos+""+" "+dn+"</sup>"
			else
				Total=Fecha+" "+Hora+"<span style='color:#60008F'>:</span>"+Minutos+""+" "+dn+"</sup>"
		}
		
		document.getElementById('Fecha_Reloj').innerHTML = Total 
		Hoy.setSeconds(Hoy.getSeconds() +1)
		alternate=(alternate==0)? 1 : 0
	
		setTimeout("Reloj()",1000)  
} 

// ------------------------------------------------------------------------------------------------
//  Sets/unsets the pointer and marker in browse mode
// ------------------------------------------------------------------------------------------------
/* @param   object    the table row
 * @param   interger  the row number
 * @param   string    the action calling this script (over, out or click)
 * @param   string    the default background color
 * @param   string    the color to use for mouseover
 * @param   string    the color to use for marking a row
 *
 * @return  boolean  whether pointer is set or not
 */
function setPointer(theRow, theRowNum, theAction, theDefaultColor, thePointerColor, theMarkColor)
{
/**
 * This array is used to remember mark status of rows in browse mode
*/
	var marked_row = new Array;

    var theCells = null;

    // 1. Pointer and mark feature are disabled or the browser can't get the
    //    row -> exits
    if ((thePointerColor == '' && theMarkColor == '')
        || typeof(theRow.style) == 'undefined') {
        return false;
    }

    // 2. Gets the current row and exits if the browser can't get it
    if (typeof(document.getElementsByTagName) != 'undefined') {
        theCells = theRow.getElementsByTagName('td');
    }
    else if (typeof(theRow.cells) != 'undefined') {
        theCells = theRow.cells;
    }
    else {
        return false;
    }

    // 3. Gets the current color...
    var rowCellsCnt  = theCells.length;
    var domDetect    = null;
    var currentColor = null;
    var newColor     = null;

	// 3.1 ... with DOM compatible browsers except Opera that does not return
    //         valid values with "getAttribute"
	if (typeof(window.opera) == 'undefined' && typeof(theCells[0].getAttribute) != 'undefined') {
        currentColor = theCells[0].getAttribute('bgcolor');
        domDetect    = true;
    }
    // 3.2 ... with other browsers
    else {
        currentColor = theCells[0].style.backgroundColor;
        domDetect    = false;
    } // end 3

    // 4. Defines the new color
    // 4.1 Current color is the default one
    if (currentColor == ''
        || currentColor.toLowerCase() == theDefaultColor.toLowerCase()) {
        if (theAction == 'over' && thePointerColor != '') {
            newColor              = thePointerColor;
        }
        else if (theAction == 'click' && theMarkColor != '') {
            newColor              = theMarkColor;
            marked_row[theRowNum] = true;
        }
    }
    // 4.1.2 Current color is the pointer one
    else if (currentColor.toLowerCase() == thePointerColor.toLowerCase()
             && (typeof(marked_row[theRowNum]) == 'undefined' || !marked_row[theRowNum])) {
        if (theAction == 'out') {
            newColor              = theDefaultColor;
        }
        else if (theAction == 'click' && theMarkColor != '') {
            newColor              = theMarkColor;
            marked_row[theRowNum] = true;
        }
    }
    // 4.1.3 Current color is the marker one
    else if (currentColor.toLowerCase() == theMarkColor.toLowerCase()) {
        if (theAction == 'click') {
            newColor              = (thePointerColor != '')
                                  ? thePointerColor
                                  : theDefaultColor;
            marked_row[theRowNum] = (typeof(marked_row[theRowNum]) == 'undefined' || !marked_row[theRowNum])
                                  ? true
                                  : null;
        }
    } // end 4

    // 5. Sets the new color...
    if (newColor) {
        var c = null;
        // 5.1 ... with DOM compatible browsers except Opera
        if (domDetect) {
            for (c = 0; c < rowCellsCnt; c++) {
                theCells[c].setAttribute('bgcolor', newColor, 0);
            } // end for
        }
        // 5.2 ... with other browsers
        else {
            for (c = 0; c < rowCellsCnt; c++) {
                theCells[c].style.backgroundColor = newColor;
			}
        }
    } // end 5

    return true;
} // end of the 'setPointer()' function
//-------------------------------AJAX-----------------------------------------
function nuevoAjax() {
	var xmlhttp=false;
	try {
		xmlhttp=new ActiveXObject("Msxml2.XMLHTTP");
	} catch (e) {
		try {
			xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
		} catch (E) {
			xmlhttp=false;
		}
	}
	if (!xmlhttp && typeof XMLHttpRequest!='undefineds') {
		xmlhttp=new XMLHttpRequest();
	}
	return xmlhttp;
}
//-------------------------------AJAX-----------------------------------------
function PasarAMayusculas2(event) {

/*var key = window.event?e.keyCode : e.which;
	var keychar = String.fromCharCode(key);
	reg = /\d/;
	return !reg.test(keychar);
*/
	
  	if (is_ns4)	    
		teclaCodigo = tecla.which
    else
   	   teclaCodigo = event.keyCode
				
    var teclaReal   = String.fromCharCode (teclaCodigo);
	alert("Código de la tecla: " + teclaCodigo + "\nTecla pulsada: " + teclaReal);

//	return teclaReal+65.0;
}
//------------------------------------------------------------------------------
function PasarAMayusculas(campo) {

var elSelect = document.getElementById(campo);
	elSelect.value = elSelect.value.toUpperCase();
	
/*	
	var cajaTexto = EncontrarObjeto(campo);

	// IE
	if ( (ua_vers >= 4) && is_ie && is_win)	{  

			if (cajaTexto.isTextEdit) 	{
			
			cajaTexto.focus();
			var sel = document.selection;
			var rng = sel.createRange();
			alert(sel);
			alert(rng);
			rng.colapse;
			if((sel.type == "Text" || sel.type == "None") && rng != null)
			{
				rng.text = Texto+rng.text;
			}
		}
	}
	//----------------------------------------
	// It's MOZZY!
	//----------------------------------------	
	else if ( !isNaN(cajaTexto.selectionEnd) ) 	{ 
	
		var ss = cajaTexto.selectionStart;
		var txtAntes = (cajaTexto.value).substring(0,ss-1);
		var txtCambio = (cajaTexto.value).substring(ss-1,ss);
		var txtDespues = (cajaTexto.value).substring(ss,cajaTexto.textLength);
		
		cajaTexto.value=txtAntes.toUpperCase()+txtCambio.toUpperCase()+txtDespues.toUpperCase();
		cajaTexto.selectionStart = ss;
		cajaTexto.selectionEnd   = ss;
		
	}
	//----------------------------------------
	// It's CRAPPY!
	//----------------------------------------
	else {
		//CajaTexto.value += Texto;
	}
	
	cajaTexto.focus();
	
	return true;
*/	
}
//----------------------------------------------------------------------------
function CambiarEstado_Visibilidad(TheTR,estado)	{

	// TheTR: corresponde al nombre del objeto que define la fila.
	var DataTR = eval('document.getElementById("' + TheTR + '")');

	if (estado=="visible") { 
		if (navigator.appName=="Microsoft Internet Explorer") { 	// Para Explorer
			DataTR.style.display="block";
		} else {	// Para Mozzilla u otros
			DataTR.style.visibility="visible";
			DataTR.style.position="relative";
			DataTR.parentNode.style.padding="9px 10px 14px 10px";
		}
	} 
 
	if (estado=="invisible") { 
		if (navigator.appName=="Microsoft Internet Explorer") { 	// Para Explorer
			DataTR.style.display="none";
		} else {	// Para Mozzilla u otros
			DataTR.style.visibility="hidden";
			DataTR.style.position="absolute";
			DataTR.parentNode.style.padding="0px 0px 0px 0px";
		}
	}
	return true;
}
//----------------------------------------------------------------------------
// Obtiene el estado actual
function ObtenerEstado_Visibilidad(TheTR)	{

	var DataTR = eval('document.getElementById("' + TheTR + '")');
	var estado="";
	
	if (navigator.appName=="Microsoft Internet Explorer") { 	// Para Explorer
		if (DataTR.style.display=="block" || DataTR.style.display=="" )	
			estado = "visible";
		else 
			estado = "invisible";		
	} else {	// Para Mozzilla u otros
		if (DataTR.style.visibility=="visible" || DataTR.style.visibility=="" )	
			estado = "visible";
		else 
			estado = "invisible";
	}
	
	return estado;
}
//----------------------------------------------------------------------------
// Invierte el estado actual del grupo de 	visible => invisible.
//											invisible => visible.
function InvertirEstado_Visibilidad(TheTR)	{

   var estadoActual = ObtenerEstado_Visibilidad(TheTR);		// estaba para grupo

	if (estadoActual=="visible") 
		CambiarEstado_Visibilidad(TheTR,"invisible");
	else {
	   	if (estadoActual=="invisible") 
			CambiarEstado_Visibilidad(TheTR,"visible");
	}
}
//----------------------------------------------------------------------------
