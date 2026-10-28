var frm = document.addr;
//----------------------------------------------------------------------------
function Fila_contenido_grupo_inicio(idFila,visible) {

	document.write("<!-- Fila con datos contenido -->");

	if (navigator.appName=="Microsoft Internet Explorer") {
	  if (visible=="SI")
		  document.write("<tr id='"+idFila+"' style='display:block'>");
	  else	
		  document.write("<tr id='"+idFila+"' style='display:none'>");	  

	  document.write("<td colspan=2 style='padding:9px 10px 14px 10px'>");

	} else {

	    document.write("<tr>");

		if (visible=="SI")
		   document.write("<td colspan=2 style='padding:9px 10px 14px 10px'><div id='"+idFila+"' style=''>");
		else   
	       document.write("<td colspan=2 style='padding:9px 10px 14px 10px'><div id='"+idFila+"' style='visibility:hidden;position:absolute'>");
	}	
}	   
//----------------------------------------------------------------------------
function Fila_contenido_grupo_final() {
   document.write("</td>");
   document.write("</tr>");
}
//----------------------------------------------------------------------------
function Grupo_CambiarEstado(TheTR,estado)	{

// Abre o Cierra un grupo de elementos. 
// TheTR: corresponde al nombre del objeto que define la fila.
// img: "NO" o el nombre del objeto que define la fila. 

// Nota: el objeto de la imagen es 'img_'+TheTR.(Se fija en Fila_inicial_grupo)
//		 el objeto oculto donde es 'hid_'+ TheTR. (Se fija en Fila_inicial_grupo)

var DataTR = eval('document.getElementById("' + TheTR + '")');
var campoOculto='hid_'+TheTR; 
var DataTR_estado = eval('document.getElementById("'+campoOculto+'")');

if (estado=="abierto") { // Abre un grupo
	DataTR_estado.value="SI";
	if (navigator.appName=="Microsoft Internet Explorer") { 	// Para Explorer
		DataTR.style.display="block";
	} else {	// Para Mozzilla u otros
		DataTR.style.visibility="visible";
		DataTR.style.position="relative";
		DataTR.parentNode.style.padding="9px 10px 14px 10px";
	}
	document.images['img_'+TheTR+'_estado'].src='images/boton_grupo_open.gif';
} 
 
if (estado=="cerrado") { // Cierra un grupo
	DataTR_estado.value="NO";
	if (navigator.appName=="Microsoft Internet Explorer") { 	// Para Explorer
		DataTR.style.display="none";
	} else {	// Para Mozzilla u otros
			DataTR.style.visibility="hidden";
			DataTR.style.position="absolute";
			DataTR.parentNode.style.padding="0px 0px 0px 0px";
	}
	document.images['img_'+TheTR+'_estado'].src='images/boton_grupo_close.gif';
}
return true;
}
//----------------------------------------------------------------------------
// Obtiene el estado actual del grupo
function Grupo_ObtenerEstado(TheTR)	{

	var DataTR = eval('document.getElementById("' + TheTR + '")');
	var estado="";
	
	if (navigator.appName=="Microsoft Internet Explorer") { 	// Para Explorer
		if (DataTR.style.display=="block" || DataTR.style.display=="" )	
			estado = "abierto";
		else 
			estado = "cerrado";		
	} else {	// Para Mozzilla u otros
		if (DataTR.style.visibility=="visible" || DataTR.style.visibility=="" )	
			estado = "abierto";
		else 
			estado = "cerrado";
	}
	return estado;
}
//----------------------------------------------------------------------------
// Invierte el estado actual del grupo de 	abierto => cerrado.
//											cerrado => abierto.
function Grupo_InvertirEstado(TheTR)	{

   var estadoActual = Grupo_ObtenerEstado(TheTR);
   	if (estadoActual=="abierto") 
		Grupo_CambiarEstado(TheTR,"cerrado");
	else {
	   	if (estadoActual=="cerrado") 
			Grupo_CambiarEstado(TheTR,"abierto");
	}
}
//----------------------------------------------------------------------------
function SubGrupo_InvertirEstado(TheTR,TheSubs)	{

	var array_nom_subgrupos = new Array();	
	var pos_sepa = TheSubs.lastIndexOf(',',TheSubs.length);	
	var i_subgrupos=0;
	while (pos_sepa != -1) {
		array_nom_subgrupos[i_subgrupos]=TheSubs.substring(pos_sepa+1,TheSubs.length);		
		TheSubs=TheSubs.substring(0,pos_sepa);
		pos_sepa=TheSubs.lastIndexOf(',',TheSubs.length);
		i_subgrupos=i_subgrupos+1;
	}

	//	if (i_subgrupos!=0) 
	// ultimo elemento, verifico que no venga vacia la cadena antes de ponerlo 
	if (TheSubs!='')
		array_nom_subgrupos[i_subgrupos]=TheSubs;		
	
	var DataTR = eval('document.getElementById("' + TheTR + '")');

	// Si se esta cerrado el grupo principal, se cierran los subgrupos
	if (Grupo_ObtenerEstado(TheTR) == 'abierto' )	{ 
	 	for (i=0; i <= i_subgrupos; i++)  {
			DataTRH1 = eval('document.getElementById("'+array_nom_subgrupos[i]+'")');
			if (DataTRH1!=null) { // Si existe el subgrupo entonces le cambio el estado (para optativos)
				if (Grupo_ObtenerEstado(array_nom_subgrupos[i]) == 'abierto' )	{ 
					Grupo_InvertirEstado(array_nom_subgrupos[i]);				
				}			
			}
		}	// for 	
	} // if visible 

	// Se cierra cambia el estado del Grupo principal
	Grupo_InvertirEstado(TheTR);
}
//----------------------------------------------------------------------------
