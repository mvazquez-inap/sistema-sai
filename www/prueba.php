<?php 
require('./include.dhtml');
$conexion = new accesoBDLocal(SERVIDORBD,USUARIOBD,CLAVEBD);
$conexion->SeleccionBD(BASEDATOS);

// carga las constantes generales
FuncionesPHPLocal::CargarConstantes($conexion,array("roles"=>"si","sistema"=>SISTEMA));
$conexion->SetearAdmiGeneral(ADMIONTI);

// ve si el sistema está bloqueado
$oSistemaBloqueo = new SistemaBloqueo();
$oSistemaBloqueo->VerificarBloqueo($conexion);

$oEncabezados = new cEncabezados($conexion);
$oEncabezados->EncabezadoMenuEmergente($_SESSION['usuariocod'],$_SESSION['rolcod'],$_SESSION['jurisdid_inap']);
//-------------------------------------------------------------------------------------
$_SESSION['usuariocod']=0;
$_SESSION['rolcod']=30;
$_SESSION['jurisdid_inap']=0;

echo "<br> --------------- CURSO -----------------" ;
$oActividadCurso=new cActividadCurso($conexion);
$ArregloDatos=array('dis_fecha_desde'=>"2006-01-01",
					'dis_fecha_hasta'=>"2006-06-01",
					'pers_cuilt'=>"00000000001");
$numfilas=0;	
if(!$oActividadCurso->CreditosActividad_porPersona($ArregloDatos, $numfilas, $resultCreditos, $error, $errormail)) {
	$txt_sys_mail = "Error";
	FuncionesPHPLocal::MostrarMensaje($conexion,MSG_ERRGRAVE,"Error. ",array("archivo" => __FILE__,"funcion" => __FUNCTION__, "linea" => __LINE__),array("formato"=>FMT_TEXTO),$txt_sys_mail);
	return false;
} 
echo "<br> Cantidad de filas (creditos)" ;
echo "<br>".$numfilas;

echo "<br> Cantidad de result creditos";
while ($fila = mysqli_fetch_assoc($resultCreditos) ) {	
	print_r($fila);	
	echo "<br> ";
}

echo "<br> Cantidad de filas (actividades)" ;
echo "<br>".$numfilas;
$ArregloDatos=array('dis_fecha_desde'=>"2006-01-01",
					'dis_fecha_hasta'=>"2006-06-01",
					'pers_cuilt'=>"00000000001");

if(!$oActividadCurso->ActividadCertificada_porPersona($ArregloDatos, $numfilas, $resultAct, $error, $errormail)) {
	$txt_sys_mail = "Error";
	FuncionesPHPLocal::MostrarMensaje($conexion,MSG_ERRGRAVE,"Error,",array("archivo" => __FILE__,"funcion" => __FUNCTION__, "linea" => __LINE__),array("formato"=>FMT_TEXTO),$txt_sys_mail);
	return false;
} 
echo "<br> Cantidad de actividades";
echo "<br>".$numfilas;

echo "<br> Cantidad de actividades";
while ($fila = mysqli_fetch_assoc($resultAct) ) {	
	print_r($fila);	
	echo "<br> ";
}


echo "<br> --------------- EXTERNAS -----------------" ;
$oActividadExternaPersona=new cActividadExternaPersona($conexion);
$ArregloDatos=array('dis_fecha_desde'=>"2006-01-01",
					'dis_fecha_hasta'=>"2006-06-01",
					'pers_cuilt'=>"00000000001");
$numfilas=0;	
if(!$oActividadExternaPersona->CreditosActividad_porPersona($ArregloDatos, $numfilas, $resultCreditos, $error, $errormail)) {
	$txt_sys_mail = "Error";
	FuncionesPHPLocal::MostrarMensaje($conexion,MSG_ERRGRAVE,"Error .",array("archivo" => __FILE__,"funcion" => __FUNCTION__, "linea" => __LINE__),array("formato"=>FMT_TEXTO),$txt_sys_mail);
	return false;
} 
echo "<br> Cantidad de filas (creditos)" ;
echo "<br>".$numfilas;

echo "<br> Cantidad de result creditos";
while ($fila = mysqli_fetch_assoc($resultCreditos) ) {	
	print_r($fila);	
	echo "<br> ";
}

echo "<br> Cantidad de filas (actividades)" ;
echo "<br>".$numfilas;
$ArregloDatos=array('dis_fecha_desde'=>"2006-01-01",
					'dis_fecha_hasta'=>"2006-06-01",
					'pers_cuilt'=>"00000000001");

if(!$oActividadExternaPersona->ActividadCertificada_porPersona($ArregloDatos, $numfilas, $resultAct, $error, $errormail)) {
	$txt_sys_mail = "Error ";
	FuncionesPHPLocal::MostrarMensaje($conexion,MSG_ERRGRAVE,"Error.",array("archivo" => __FILE__,"funcion" => __FUNCTION__, "linea" => __LINE__),array("formato"=>FMT_TEXTO),$txt_sys_mail);
	return false;
} 
echo "<br> Cantidad de actividades";
echo "<br>".$numfilas;

echo "<br> Cantidad de actividades";
while ($fila = mysqli_fetch_assoc($resultAct) ) {	
	print_r($fila);	
	echo "<br> ";
}

echo "<br> --------------- AUTODESARROLLO -----------------" ;
$oActividadAutodesarrolloPersona=new cActividadAutodesarrolloPersona($conexion);
$ArregloDatos=array('dis_fecha_desde'=>"2006-01-01",
					'dis_fecha_hasta'=>"2006-06-01",
					'pers_cuilt'=>"00000000001");
$numfilas=0;	
if(!$oActividadAutodesarrolloPersona->CreditosActividad_porPersona($ArregloDatos, $numfilas, $resultCreditos, $error, $errormail)) {
	$txt_sys_mail = "Error";
	FuncionesPHPLocal::MostrarMensaje($conexion,MSG_ERRGRAVE,"Error ",array("archivo" => __FILE__,"funcion" => __FUNCTION__, "linea" => __LINE__),array("formato"=>FMT_TEXTO),$txt_sys_mail);
	return false;
} 
echo "<br> Cantidad de filas (creditos)" ;
echo "<br>".$numfilas;

echo "<br> Cantidad de result creditos";
while ($fila = mysqli_fetch_assoc($resultCreditos) ) {	
	print_r($fila);	
	echo "<br> ";
}

echo "<br> Cantidad de filas (actividades)" ;
echo "<br>".$numfilas;
$ArregloDatos=array('dis_fecha_desde'=>"2006-01-01",
					'dis_fecha_hasta'=>"2006-06-01",
					'pers_cuilt'=>"00000000001");


if(!$oActividadAutodesarrolloPersona->ActividadCertificada_porPersona($ArregloDatos, $numfilas, $resultAct, $error, $errormail)) {
	$txt_sys_mail = "Error";
	FuncionesPHPLocal::MostrarMensaje($conexion,MSG_ERRGRAVE,"Error .",array("archivo" => __FILE__,"funcion" => __FUNCTION__, "linea" => __LINE__),array("formato"=>FMT_TEXTO),$txt_sys_mail);
	return false;
} 
echo "<br> Cantidad de actividades";
echo "<br>".$numfilas;

echo "<br> Cantidad de actividades";
while ($fila = mysqli_fetch_assoc($resultAct) ) {	
	print_r($fila);	
	echo "<br> ";
}






echo "<br> --------------- TODAS JUNTAS -----------------" ;
$oActividad=new cActividad($conexion);
$ArregloDatos=array('dis_fecha_desde'=>"2006-01-01",
					'dis_fecha_hasta'=>"2006-06-01",
					'pers_cuilt'=>"00000000001");
$numfilas=0;	
if(!$oActividad->CreditosActividad_porPersona($ArregloDatos, $numfilas, $resultCreditos, $error, $errormail)) {
	$txt_sys_mail = "Error";
	FuncionesPHPLocal::MostrarMensaje($conexion,MSG_ERRGRAVE,"Error ",array("archivo" => __FILE__,"funcion" => __FUNCTION__, "linea" => __LINE__),array("formato"=>FMT_TEXTO),$txt_sys_mail);
	return false;
} 
echo "<br> Cantidad de filas (creditos)" ;
echo "<br>".$numfilas;

echo "<br> Cantidad de result creditos";
while ($fila = mysqli_fetch_assoc($resultCreditos) ) {	
	print_r($fila);	
	echo "<br> ";
}

echo "<br> Cantidad de filas (actividades)" ;
echo "<br>".$numfilas;
$ArregloDatos=array('dis_fecha_desde'=>"2006-01-01",
					'dis_fecha_hasta'=>"2006-06-01",
					'pers_cuilt'=>"00000000001");


if(!$oActividad->ActividadCertificada_porPersona($ArregloDatos, $numfilas, $resultAct, $error, $errormail)) {
	$txt_sys_mail = "Error";
	FuncionesPHPLocal::MostrarMensaje($conexion,MSG_ERRGRAVE,"Error .",array("archivo" => __FILE__,"funcion" => __FUNCTION__, "linea" => __LINE__),array("formato"=>FMT_TEXTO),$txt_sys_mail);
	return false;
} 
echo "<br> Cantidad de actividades";
echo "<br>".$numfilas;

echo "<br> Cantidad de actividades";
while ($fila = mysqli_fetch_assoc($resultAct) ) {	
	print_r($fila);	
	echo "<br> ";
}

//-------------------------------------------------------------------------------------
$oEncabezados->PieMenuEmergente(); 
?>