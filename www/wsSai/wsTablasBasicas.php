<?php 
require_once('nusoap/lib/nusoap.php');
require_once('includeWS.dhtml');

ini_set("memory_limit","64M");
error_reporting (0); 

$server = new soap_server();
$server->configureWSDL('wsSysTables', $NAMESPACE, '', 'document');
$server->wsdl->schemaTargetNAMESPACE=$NAMESPACE;
/*---------------------------------------------------------------------------*/
/* INTERFASE					    									     */
/*---------------------------------------------------------------------------*/
// - obtenerFormatos 
// ----------------------------
// 		Entrada:  nada
//		Salida :  xml (codigo, descripcion)
/*---------------------------------------------------------------------------*/
// - obtenerTipoActidad 
// ----------------------------
// 		Entrada:  nada
//		Salida :  (codigo, descripcion, formato_act)
/*---------------------------------------------------------------------------*/
// - obtenerResolucionActividad 
// ----------------------------
// 		Entrada:  nada
//		Salida :  (codigo, descripcion, formato_act)
/*---------------------------------------------------------------------------*/

/*---------------------------------------------------------------------------*/
/* DECLARACION FUNCIONES										      		 */
/*---------------------------------------------------------------------------*/
$documentation = "Retorna los códigos de formato y su descripción.";
$server->register(
        'sysTableFormatoActividad',			// nombre de la funcion
        array(), 							// parametros de entrada
        array('resultado'=>'xsd:string'),   // parametros de salida
        $NAMESPACE,
		false,                				// soapaction
		'document', 						// style
		'literal', 							// use
		$documentation            			// documentation		
);		
/*---------------------------------------------------------------------------*/
$documentation = "Retorna los código de tipos de actividad y su descripción.";
$server->register(
        'sysTableTipoActividad',			// nombre de la funcion
        array(), 							// parametros de entrada
        array('resultado'=>'xsd:string'),   // parametros de salida
        $NAMESPACE,
		false,                				// soapaction
		'document', 						// style
		'literal', 							// use
		$documentation            			// documentation		
);		
/*---------------------------------------------------------------------------*/
$documentation = "Retorna el número resolución según el tipo de actividad.";
$server->register(
        'sysTableResolucion',				// nombre de la funcion
        array(), 							// parametros de entrada
        array('resultado'=>'xsd:string'),   // parametros de salida
        $NAMESPACE,
		false,                				// soapaction
		'document', 						// style
		'literal', 							// use
		$documentation            			// documentation		
);		
/*---------------------------------------------------------------------------*/
function sysTableFormatoActividad() {

	$oSysTab = new cWsTablasBasicas ();
	$respuesta = $oSysTab->obtenerSysTable('sysTableFormatoActividad');

	if ($respuesta == WS_ERROR) 
		return new soap_fault($oSysTab->getError(),"",$oSysTab->getErrorDetalle($oSysTab->getError()),$oSysTab->getErrorDescripcion());

	return $respuesta;	
}
/*---------------------------------------------------------------------------*/
function sysTableTipoActividad() {

	$oSysTab = new cWsTablasBasicas ();
	$respuesta = $oSysTab->obtenerSysTable('sysTableTipoActividad');
	
	if ($respuesta == WS_ERROR) 
		return new soap_fault($oSysTab->getError(),"",$oSysTab->getErrorDetalle($oSysTab->getError()),$oSysTab->getErrorDescripcion());

	return $respuesta;	
}
/*---------------------------------------------------------------------------*/
function sysTableResolucion() {
	
	$oSysTab = new cWsTablasBasicas ();
	$respuesta = $oSysTab->obtenerSysTable('sysTableResolucion');

	if ($respuesta == WS_ERROR) 
		return new soap_fault($oSysTab->getError(),"",$oSysTab->getErrorDetalle($oSysTab->getError()),$oSysTab->getErrorDescripcion());

	return $respuesta;	
}
/*---------------------------------------------------------------------------*/
$HTTP_RAW_POST_DATA = isset($HTTP_RAW_POST_DATA) ? $HTTP_RAW_POST_DATA  : file_get_contents("php://input");
$server->service($HTTP_RAW_POST_DATA);
?>