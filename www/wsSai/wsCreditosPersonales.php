<?php 
require_once('nusoap/lib/nusoap.php');
require_once('includeWS.dhtml');

ini_set("memory_limit","64M");
error_reporting (0); 

$server = new soap_server();
$server->configureWSDL('wsCreditosPersonales', $NAMESPACE, '', 'document');
$server->wsdl->schemaTargetNAMESPACE=$NAMESPACE;

/*---------------------------------------------------------------------------*/
/* INTERFASE					    									     */
/*---------------------------------------------------------------------------*/

/*---------------------------------------------------------------------------*/
// - obtenerDatosPersonales
// ----------------------------
// 		Entrada:   (string) cuit
//		Salida :   datosPersonales.xsd
/*---------------------------------------------------------------------------*/

// ----------------------------
// - creditosTotal 
// ----------------------------
// 		Entrada:  (string) cuit
//				   Fechas de realizacion
//				  (string dd/mm/aaaa) fecha_inicio				
//				  (string dd/mm/aaaa) fecha_fin
//		Salida :  (int) creditos
/*---------------------------------------------------------------------------*/

// ----------------------------
// - detalleCreditosTotal 
// ----------------------------
// 		Entrada:  (string) cuit
//				   Fechas de realizacion
//				  (string dd/mm/aaaa) fecha_inicio				
//				  (string dd/mm/aaaa) fecha_fin
//		Salida :  actividadCertificada.xsd
/*---------------------------------------------------------------------------*/

// ----------------------------
// - creditosPorFormato 
// ----------------------------
// 		Entrada:  (int) formato (0,1,2,3) => (todos, curso, autodesarrollo, externa)
//				  (string) cuit
//				   Fechas de realizacion
//				  (string dd/mm/aaaa) fecha_inicio				
//				  (string dd/mm/aaaa) fecha_fin
//		Salida :  (int) creditos
/*---------------------------------------------------------------------------*/

// ----------------------------
// - detalleCreditosPorFormato
// ----------------------------
// 		Entrada:  (int) formato	=> (todos, curso, autodesarrollo, externa)
//				  (string) cuit
//				   Fechas de realizacion
//				  (string dd/mm/aaaa) fecha_inicio				
//				  (string dd/mm/aaaa) fecha_fin
//		Salida :  actividadcertifcada.xsd
/*---------------------------------------------------------------------------*/

/*---------------------------------------------------------------------------*/
/* DECLARACION FUNCIONES										      		 */
/*---------------------------------------------------------------------------*/
$documentation = "Dado un cuit (string), ";
$documentation .= "retorna los datos personales del agente con dicho cuit.";
$server->register(
        'datosPersonales',					// nombre de la funcion
        array('cuit'=>'xsd:string' ), 		// parametros de entrada
        array('resultado'=>'xsd:string'),   // parametros de salida
        $NAMESPACE,
		false,                				// soapaction
		'document', 						// style
		'literal', 							// use
		$documentation            			// documentation		
);		
/*--------------------------------------------------------------------*/
$documentation = "Dado un cuit (string), una fecha desde (string: dd/mm/aaaa) y fecha hasta (string: dd/mm/aaaa), ";
$documentation .= "retorna el total de créditos (int) certificados por INAP, para dicho cuit por actividades realizadas entre las fechas dadas.";
$server->register(
        'creditosTotal',				// nombre de la funcion
        array('cuit'=>'xsd:string', 'fecha_desde'=>'xsd:string', 'fecha_hasta'=>'xsd:string'), // parametros de entrada
        array('creditos'=>'xsd:int'),  // parametros de salida
        $NAMESPACE,
		false,                			// soapaction
		'document', 					// style
		'literal', 						// use
		$documentation            		// documentation		
);		
/*--------------------------------------------------------------------*/
$documentation = "Dado un cuit (string), una fecha desde (string: dd/mm/aaaa) y fecha hasta (string: dd/mm/aaaa), ";
$documentation .= "retorna las actividades certificados por INAP, para dicho cuit entre las fechas dadas.";
$server->register(
        'detalleCreditosTotal',				// nombre de la funcion
        array('cuit'=>'xsd:string', 'fecha_desde'=>'xsd:string','fecha_hasta'=>'xsd:string'), // parametros de entrada
        array('resultado'=>'xsd:string'),   // parametros de salida
        $NAMESPACE,
		false,                				// soapaction
		'document', 						// style
		'literal', 							// use
		$documentation            			// documentation		
);		
/*--------------------------------------------------------------------*/
$documentation = "Dado un cuit (string), una fecha desde (string: dd/mm/aaaa), fecha hasta (string: dd/mm/aaaa) y el formato (0:Todos,1:curso,2:autodesarrollo,3:externa), ";
$documentation .= "retorna el total de créditos certificados por INAP, para dicho cuit por actividades realizadas entre las fechas dadas del formato indicado.";
$server->register(
        'creditosPorFormato',			// nombre de la funcion
        array('formact_codigo'=>'xsd:int', 'cuit'=>'xsd:string', 'fecha_desde'=>'xsd:string','fecha_hasta'=>'xsd:string'), // parametros de entrada
        array('creditos'=>'xsd:int'),  // parametros de salida
        $NAMESPACE,
		false,                			// soapaction
		'document', 					// style
		'literal', 						// use
		$documentation            		// documentation		
);		
/*--------------------------------------------------------------------*/
$documentation = "Dado un cuit (string), una fecha desde (string: dd/mm/aaaa), fecha hasta (string: dd/mm/aaaa) y el formato (0:Todos,1:curso,2:autodesarrollo,3:externa), ";
$documentation .= "retorna las actividades certificados por INAP, para dicho cuit por actividades realizadas entre las fechas dadas del formato indicado.";
$server->register(
        'detalleCreditosPorFormato',		// nombre de la funcion
        array('formact_codigo'=>'xsd:int', 'cuit'=>'xsd:string', 'fecha_desde'=>'xsd:string','fecha_hasta'=>'xsd:string'), // parametros de entrada
        array('resultado'=>'xsd:string'),   // parametros de salida
        $NAMESPACE,
		false,                				// soapaction
		'document', 						// style
		'literal', 							// use
		$documentation            			// documentation		
);		
/*--------------------------------------------------------------------*/
/* DEFINICION DE FUNCIONES											  */
/*--------------------------------------------------------------------*/
function creditosTotal($cuit,$fecha_desde,$fecha_hasta) {

	$array_param=array(	'pers_cuilt'=>$cuit,
						'fecha_inicio'=>$fecha_desde,
						'fecha_fin'=>$fecha_hasta
						);

	$oWS = new cWsCreditosPersonales();
	
	$respuesta = $oWS->obtenerCreditos($array_param);

	if ($respuesta == WS_ERROR) 
		return new soap_fault($oWS->getError(),"",$oWS->getErrorDetalle($oWS->getError()),$oWS->getErrorDescripcion());


	return $respuesta;
}
/*--------------------------------------------------------------------*/
function detalleCreditosTotal($cuit,$fecha_desde,$fecha_hasta) {

	$array_param=array(	'pers_cuilt'=>$cuit,
						'fecha_inicio'=>$fecha_desde,
						'fecha_fin'=>$fecha_hasta
						);

	$oWS = new cWsCreditosPersonales();
	$respuesta = $oWS->obtenerDetalleCreditos($array_param);
	
	if ($respuesta == WS_ERROR) 
		return new soap_fault($oWS->getError(),"",$oWS->getErrorDetalle($oWS->getError()),$oWS->getErrorDescripcion());
		
	return $respuesta;	
}
/*--------------------------------------------------------------------*/
// CREDITOS POR FORMATO
/*--------------------------------------------------------------------*/
function creditosPorFormato($formato,$cuit,$fecha_desde,$fecha_hasta) {

	$array_param=array(	'pers_cuilt'=>$cuit,
						'fecha_inicio'=>$fecha_desde,
						'fecha_fin'=>$fecha_hasta,
						'formact_codigo'=>$formato
						);

	$oWS = new cWsCreditosPersonales();
	$respuesta = $oWS->obtenerCreditos($array_param,$formato);

	if ($respuesta == WS_ERROR) 
		return new soap_fault($oWS->getError(),"",$oWS->getErrorDetalle($oWS->getError()),$oWS->getErrorDescripcion());

	return $respuesta;
}
/*--------------------------------------------------------------------*/
function detalleCreditosPorFormato($formato,$cuit,$fecha_desde,$fecha_hasta) {

	$array_param=array(	'pers_cuilt'=>$cuit,
						'fecha_inicio'=>$fecha_desde,
						'fecha_fin'=>$fecha_hasta,
						'formact_codigo'=>$formato
						);
	
	$oWS = new cWsCreditosPersonales();
	$respuesta = $oWS->obtenerDetalleCreditos($array_param,$formato);
	
	if ($respuesta == WS_ERROR) 
		return new soap_fault($oWS->getError(),"",$oWS->getErrorDetalle($oWS->getError()),$oWS->getErrorDescripcion());
		
	return $respuesta;	
}
/*--------------------------------------------------------------------*/
function datosPersonales($cuit) {

	$array_param=array('pers_cuilt'=>$cuit);
	
	$oWS = new cWsCreditosPersonales();
	$respuesta = $oWS->obtenerDatosPersonales($array_param);
	
	if ($respuesta == WS_ERROR) 
		return new soap_fault($oWS->getError(),"",$oWS->getErrorDetalle($oWS->getError()),$oWS->getErrorDescripcion());

	return $respuesta;	
}
/*--------------------------------------------------------------------*/
$HTTP_RAW_POST_DATA = isset($HTTP_RAW_POST_DATA) ? $HTTP_RAW_POST_DATA  : file_get_contents("php://input");
$server->service($HTTP_RAW_POST_DATA);
?>