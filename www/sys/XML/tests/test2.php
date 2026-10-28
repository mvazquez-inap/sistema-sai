
<?php

$dtd = "attributes.dtd";

$xml = "attributes_good.xml";
if (!$xml) {
	include '../../XML/DTD.php';
	$a = new XML_DTD_Parser;
	print_r($a->parse($dtd));
} else {
	include '../../XML/DTD/XmlValidator.php';
	$a = new XML_DTD_XmlValidator;
	if (!$a->isValid($dtd, $xml)) {
		echo $a->getMessage();
	}
}
function help() {
	echo "Usage: test.php <dtd file> [<xml file>]\n";
	echo "Passing only <dtd file> will dump the parsed DTD Tree\n";
	echo "Passing both, will try to validate <xml file> with <dtd file>\n";
	exit;
}
?>