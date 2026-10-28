<?php

require_once("class.fpdf_table.php");
require_once("table_def.php");

$pdf=new FPDF_TABLE();
$pdf->SetAutoPageBreak(true, 20);
$pdf->SetTopMargin(30);
$pdf->AddPage();

$columns = 5; //five columns

$pdf->SetStyle("p","times","",10,"130,0,30");
$pdf->SetStyle("pb","times","B",11,"130,0,30");
$pdf->SetStyle("t1","arial","",11,"254,252,222");
$pdf->SetStyle("t1","arial","",11,"0,151,200");
$pdf->SetStyle("t2","arial","",11,"0,151,200");
$pdf->SetStyle("t3","times","B",14,"203,0,48");
$pdf->SetStyle("t4","arial","BI",11,"0,151,200");
$pdf->SetStyle("hh","times","B",11,"255,189,12");
$pdf->SetStyle("font","helvetica","",10,"0,0,255");
$pdf->SetStyle("style","helvetica","BI",10,"0,0,220");
$pdf->SetStyle("size","times","BI",13,"0,0,120");
$pdf->SetStyle("color","times","BI",13,"0,255,255");
$pdf->SetStyle("ss","arial","",7,"203,0,48");     
    
$ttxt[1] = "<size>Tag-Based MultiCell TABLE</size>

Done by <t1 href='mailto:klodoma@ar-sd.net'>Bintintan Andrei</t1>";
$ttxt[2] = "<p>
<t3>Description</t3>

\tThis method allows printing <t4><TAG></t4> formatted text with line breaks. They can be automatic (as soon as the text reaches the right border of the cell) or explicit (via the <pb>\\n</pb> character). As many cells as necessary are output, one below the other.
Text can be <hh>aligned</hh>, <hh>cente~~~red</hh> or <hh>justified</hh>. Different <font>Font</font>, <size>Sizes</size>, <style>Styles</style>, <color>Colors</color> can be used. The cell block can be framed and the background painted. The behavior/paramaters of the method are the same as to the <t2 href='http://www.fpdf.org/en/doc/multicell.htm'>FPDF Multicell method</t2>. <style href='www.fpdf.org'>Links</style> can be used in any tag.
\t<t4>TAB</t4> spaces (<pb>\\t</pb>) can be used. The <t4>ttags</t4> tag name is reserved for the TAB SPACES.
\tVariable Y relative positions can be used for <ss ypos='-0.8'>Subscript</ss> or <ss ypos='1.1'>Superscript</ss>.</p>
<style>
\t<hh size='50' >Controlled Tab Space~~~</hh> - Tab Space 1
\t<hh size='60' > ~~~</hh><font> - Tab Space 2</font>
\t<hh size='60' > ~~~</hh> - Tab Space 2
\t<hh size='70' > ~~~</hh><hh> - Tab Space 3</hh>
\t<hh size='50' > ~~~</hh> - Tab Space 1
\t<hh size='60' > ~~~</hh><t4> - Tab Space 2</t4>
</style>
\tIf no <t4><TAG></t4> is specified then the FPDF current settings are used.\n\n";
$ttxt[3] ="\t\t<style>Best Regards</style>";    

	
	//we initialize the table class
	$pdf->Table_Init($columns, true, true);

	$table_subtype = $table_default_table_type;
	$pdf->Set_Table_Type($table_subtype);
	
	//TABLE HEADER SETTINGS
	$header_subtype = $table_default_header_type;
	for($i=0; $i<$columns; $i++) $header_type[$i] = $table_default_header_type;

	$header_type[0]['WIDTH'] = 20;
	$header_type[1]['WIDTH'] = 30;
	$header_type[2]['WIDTH'] = 40;
	$header_type[3]['WIDTH'] = 40;
	$header_type[4]['WIDTH'] = 20;
	
	$header_type[0]['TEXT'] = "Header 1";
	$header_type[1]['TEXT'] = "Header 2 With COLSPAN";
	$header_type[2]['TEXT'] = "Header 3";
	$header_type[3]['TEXT'] = "Header 4";
	$header_type[4]['TEXT'] = "Header 5";
	
	$header_type[1]['COLSPAN'] = "2";

	//set the header type
	$pdf->Set_Header_Type($header_type);
	
	$pdf->Draw_Header();
	
	
	//TABLE DATA SETTINGS
	$data_subtype = $table_default_data_type;
	
	$data_type = Array();//reset the array
	for ($i=0; $i<$columns; $i++) $data_type[$i] = $data_subtype;

	$pdf->Set_Data_Type($data_type);
	
	$fsize = 5;
	$colspan = 1;
	$rr = 255;

	for ($j=0; $j<30; $j++)
	{
		$data = Array();
		$data[0]['TEXT'] = "No.$j";
		$data[1]['TEXT'] = "Test Test - $j";
		$data[2]['TEXT'] = "Test Test - $j";
		$data[3]['TEXT'] = "Text Longer <p href='www.google.com'>TexTest Longer Text</p> Test Longer Text - $j";
		$data[4]['TEXT'] = "Test text2 - $j";
		
		$data[0]['T_SIZE'] = $fsize;
		$data[1]['T_SIZE'] = 13 - $fsize;
		$data[3]['T_SIZE'] = 14 - $fsize;
		
		$data[0]['T_COLOR'] = array($rr,0,0);
		$data[0]['BG_COLOR'] = array($rr,$rr,$rr);
		$data[3]['T_COLOR'] = array($rr,240,240);
		$data[3]['BG_COLOR'] = array($rr,100,135);

		$fsize++;
		if ($fsize > 11) $fsize = 5;

		if ($j>3 && $j<13){
			$data[0]['TEXT'] = "Colspan Example$j";
			$data[0]['COLSPAN'] = $colspan;
			$data[0]['BG_COLOR'] = array($rr,0,0);
			$data[0]['T_COLOR'] = array(255,255,$rr);
			$colspan++;
			if ($colspan>5) $colspan = 1;
		}

		if ($j>15 && $j<25){
			$data[2]['TEXT'] = "Colspan Example$j";
			$data[2]['COLSPAN'] = $colspan;
			$data[2]['BG_COLOR'] = array($rr,0,0);
			$data[2]['T_COLOR'] = array(255,255,$rr);
			$colspan++;
			if ($colspan>3) $colspan = 1;
		}

		if ($j>1){
			$data[2]['BG_COLOR'] = array(255-$rr,$rr,$rr);
			$data[2]['T_COLOR'] = array(255,255,$rr);
		}

		if ($j==0){
			$data[0]['TEXT'] = "Top Right Align <p>Align Top</p> Right Right Align ";
			$data[0]['T_ALIGN'] = "R";
			$data[0]['V_ALIGN'] = "T";
			
			$data[1]['TEXT'] = "Middle Center Align Bold Italic";
			$data[1]['T_ALIGN'] = "C";
			$data[1]['T_TYPE'] = "BI";
			$data[1]['V_ALIGN'] = "M";
			
			$data[2]['TEXT'] = "\n\n\n\n\nBottom Left Align";
			$data[2]['T_ALIGN'] = "L";
			$data[2]['V_ALIGN'] = "B";
			
			$data[3]['TEXT'] = "Middle Justified Align Longer text";
			$data[3]['T_ALIGN'] = "J";
			$data[3]['V_ALIGN'] = "M";
			
			$data[4]['TEXT'] = "TOP RIGHT Align";
			$data[4]['T_ALIGN'] = "R";
			$data[4]['V_ALIGN'] = "T";
		}
        
		if ($j>0 and $j<4){
			$data[0]['TEXT'] = "";
			$data[1]['TEXT'] = "";
			$data[2]['TEXT'] = "";
			$data[3]['TEXT'] = "";
			$data[4]['TEXT'] = "";
            $data[$j-1]['TEXT'] = $ttxt[$j];
            $data[$j-1]['COLSPAN'] = 4;
            $data[$j-1]['T_ALIGN'] = "J";
            $data[$j-1]['LN_SIZE'] = 5;
		}

        if ($j== 14) {
            $data[1]['TEXT'] = "<size>Colspan = 4 and ... this\nCELL\nIS\nSPLITTED. Turn this split off with:\nFPDF_TABLE::Set_Table_SplitMode(true(default)/false) function</size>";
            $data[1]['T_ALIGN'] = "C";
            $data[1]['BG_COLOR'] = array(240,245,221);
            $data[1]['COLSPAN'] = 4;
        }
        

		$rr -= 25;
		if ($rr<100) $rr = 255;

		$pdf->Draw_Data($data);
	}

	$pdf->Draw_Table_Border();

	$pdf->Output();

?>