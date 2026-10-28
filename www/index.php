<?php 
date_default_timezone_set('America/Buenos_Aires');

require('./include.dhtml');
require_once('SysONTIMensajesInternos.dhtml');

$conexion = new accesoBDLocal(SERVIDORBD,USUARIOBD,CLAVEBD);
$conexion->SeleccionBD(BASEDATOS);

// carga las constantes generales
FuncionesPHPLocal::CargarConstantes($conexion,array("roles"=>"si","sistema"=>SISTEMA));
$conexion->SetearAdmiGeneral(ADMIONTI);

// arma las variables de sesion y verifica si se tiene permisos
$sesion = new Sesion($conexion,true); // Inicia session y borra todo

// ver constantes definidas	
// print_r(get_defined_constants()); 

// ve si el sistema está bloqueado
$oSistemaBloqueo = new SistemaBloqueo();
$oSistemaBloqueo->VerificarBloqueo($conexion);

$oEncabezados = new cEncabezados($conexion);
$oEncabezados->EncabezadoMenuEmergente($_SESSION['usuariocod'],$_SESSION['rolcod'],$_SESSION['jurisdid_inap']);

?>
<SCRIPT LANGUAGE="JavaScript" type="text/javascript">
function ValidarJS(formulario) 
{
	if (formulario.usuariocuit.value=="" || !ValidarContenido(formulario.usuariocuit.value,"CUIT"))
	{
		alert("El CUIT / CUIL / CDI no es válido");
		formulario.usuariocuit.focus();
		return false;
	}
	else if (formulario.usuarioclave.value=="")
	{
		alert("Debe ingresar su contraseña");
		formulario.usuarioclave.focus();
		return false;
	}
	else
		return true;
}
</script>

<form name="formulario" action="usuario_valida.dhtml" method="post">
<br><br><br> 
<br /><br />
<div align='center'>
<table style="margin-top:60px" width="300"  border="0" cellpadding="2" cellspacing="3" class="textoTablaDato">
  <tr>
	<td width="45%" class="colorLineaMenuIzq">&nbsp;</td>
	<td width="55%" align="center" class="colorTitulosGrupo"><span class="textoIngresoSistema">Ingreso al Sistema<br></span></td>
  </tr>
  <tr>
	<td align="left" class="textoEtiqueta">CUIT / CUIL / CDI </td>
	<td align="center" class="colorFondoSeleccion" style="padding:5px;" ><input name="usuariocuit" type="text" class="textoInput" style="text-align:left; padding:4px;" size="12" maxlength="11" ></td>
  </tr>  
    <tr>
	<td align="left" class="textoEtiqueta">Clave</td>
	<td align="center" class="colorFondoSeleccion" style="padding:5px;"><input name="usuarioclave" type="password" class="textoInput" style="text-align:left; padding:4px;" size="12" maxlength="12"></td>
  </tr>  
</table>
<br>

<input type="submit" name="botoningresar" class="botones" value="Conectar" onClick="return ValidarJS(formulario)">
<br><br><a  class="textoTablaDato linkFondoBlanco" href="usuario_olvidopass.dhtml">Olvidé mi contraseña</a>
</div>
</form>
<?php 
$oEncabezados->PieMenuEmergente(); 
?>

