<?php
/* vim: set expandtab tabstop=4 shiftwidth=4: */
// +----------------------------------------------------------------------+
// | PHP version 4                                                        |
// +----------------------------------------------------------------------+
// | Copyright (c) 1997-2003 The PHP Group                                |
// +----------------------------------------------------------------------+
// | This source file is subject to version 3.0 of the PHP license,       |
// | that is bundled with this package in the file LICENSE, and is        |
// | available through the world-wide-web at                              |
// | http://www.php.net/license/3_0.txt.                                  |
// | If you did not receive a copy of the PHP license and are unable to   |
// | obtain it through the world-wide-web, please send a note to          |
// | license@php.net so we can mail you a copy immediately.               |
// +----------------------------------------------------------------------+
// | Authors: Kouber Saparev <kouber@php.net>                             |
// +----------------------------------------------------------------------+
//
// $Id: lang.bg.php,v 1.4 2004/10/22 18:22:52 kouber Exp $

/**
 * Include needed files
 */
require_once("Numbers/Words.php");

/**
 * Class for translating numbers into Bulgarian.
 *
 * @author Kouber Saparev <kouber@php.net> 
 * @package Numbers_Words
 */
class Numbers_Words_bg extends Numbers_Words
{

    // {{{ properties

    /**
     * Locale name.
     * @var string
     * @access public
     */
    var $locale      = 'bg';

    /**
     * Language name in English.
     * @var string
     * @access public
     */
    var $lang        = 'Bulgarian';

    /**
     * Native language name.
     * @var string
     * @access public
     */
    var $lang_native = 'Áúëãàðñêè';

    /**
     * Some miscellaneous words and language constructs.
     * @var string
     * @access private
     */
    var $_misc_strings = array(
        'deset'=>'äåñåò',           // "ten"
        'edinadeset'=>'åäèíàäåñåò', // "eleven"
        'na'=>'íà',                 // liaison particle for 12 to 19
        'sto'=>'ñòî',               // "hundred"
        'sta'=>'ñòà',               // suffix for 2 and 3 hundred
        'stotin'=>'ñòîòèí',         // suffix for 4 to 9 hundred
        'hiliadi'=>'õèëÿäè'         // plural form of "thousand"
    );


    /**
     * The words for digits (except zero). Note that, there are three genders for them (neuter, masculine and feminine).
     * The words for 3 to 9 (masculine) and for 2 to 9 (feminine) are the same as neuter, so they're filled
     * in the _initDigits() method, which is invoked from the constructor.
     * @var string
     * @access private
     */
    var $_digits = array(
        0=>array(1=>"åäíî", "äâå", "òðè", "÷åòèðè", "ïåò", "øåñò", "ñåäåì", "îñåì", "äåâåò"), // neuter
        1=>array(1=>'åäèí', 'äâà'),                                                           // masculine
       -1=>array(1=>'åäíà')                                                                   // feminine
    );

    /**
     * A flag, that determines if the _digits array is filled for masculine and feminine genders.
     * @var string
     * @access private
     */
    var $_digits_initialized = false;

    /**
     * A flag, that determines if the "and" word is placed already before the last non-empty group of digits.
     * @var string
     * @access private
     */
    var $_last_and = false;

    /**
     * The word for zero.
     * @var string
     * @access private
     */
    var $_zero = 'íóëà';

    /**
     * The word for infinity.
     * @var string
     * @access private
     */
    var $_infinity = 'áåçêðàéíîñò';

    /**
     * The word for the "and" language construct.
     * @var string
     * @access private
     */
    var $_and = 'è';
    
    /**
     * The word separator.
     * @var string
     * @access private
     */
    var $_sep = ' ';

    /**
     * The word for the minus sign.
     * @var string
     * @access private
     */
    var $_minus = 'ìèíóñ'; // minus sign

    /**
     * The plural suffix (except for thousand).
     * @var string
     * @access private
     */
    var $_plural = 'à'; // plural suffix

    /**
     * The suffixes for exponents (singular).
     * @var array
     * @access private
     */
    var $_exponent = array(
          0 => '',
          3 => 'õèëÿäà',
          6 => 'ìèëèîí',
          9 => 'ìèëèàðä',
         12 => 'òðèëèîí',
         15 => 'êâàäðèëèîí',
         18 => 'êâèíòèëèîí',
         21 => 'ñåêñòèëèîí',
         24 => 'ñåïòèëèîí',
         27 => 'îêòèëèîí',
         30 => 'íîíàëèîí',
         33 => 'äåêàëèîí',
         36 => 'óíäåêàëèîí',
         39 => 'äóîäåêàëèîí',
         42 => 'òðåäåêàëèîí',
         45 => 'êâàòîðäåêàëèîí',
         48 => 'êâèíòäåêàëèîí',
         51 => 'ñåêñäåêàëèîí',
         54 => 'ñåïòäåêàëèîí',
         57 => 'îêòîäåêàëèîí',
         60 => 'íîâåìäåêàëèîí',
         63 => 'âèãèíòèëèîí',
         66 => 'óíâèãèíòèëèîí',
         69 => 'äóîâèãèíòèëèîí',
         72 => 'òðåâèãèíòèëèîí',
         75 => 'êâàòîðâèãèíòèëèîí',
         78 => 'êâèíâèãèíòèëèîí',
         81 => 'ñåêñâèãèíòèëèîí',
         84 => 'ñåïòåíâèãèíòèëèîí',
         87 => 'îêòîâèãèíòèëèîí',
         90 => 'íîâåìâèãèíòèëèîí',
         93 => 'òðèãèíòèëèîí',
         96 => 'óíòðèãèíòèëèîí',
         99 => 'äóîòðèãèíòèëèîí',
        102 => 'òðåòðèãèíòèëèîí',
        105 => 'êâàòîðòðèãèíòèëèîí',
        108 => 'êâèíòðèãèíòèëèîí',
        111 => 'ñåêñòðèãèíòèëèîí',
        114 => 'ñåïòåíòðèãèíòèëèîí',
        117 => 'îêòîòðèãèíòèëèîí',
        120 => 'íîâåìòðèãèíòèëèîí',
        123 => 'êâàäðàãèíòèëèîí',
        126 => 'óíêâàäðàãèíòèëèîí',
        129 => 'äóîêâàäðàãèíòèëèîí',
        132 => 'òðåêâàäðàãèíòèëèîí',
        135 => 'êâàòîðêâàäðàãèíòèëèîí',
        138 => 'êâèíêâàäðàãèíòèëèîí',
        141 => 'ñåêñêâàäðàãèíòèëèîí',
        144 => 'ñåïòåíêâàäðàãèíòèëèîí',
        147 => 'îêòîêâàäðàãèíòèëèîí',
        150 => 'íîâåìêâàäðàãèíòèëèîí',
        153 => 'êâèíêâàãèíòèëèîí',
        156 => 'óíêâèíêàãèíòèëèîí',
        159 => 'äóîêâèíêàãèíòèëèîí',
        162 => 'òðåêâèíêàãèíòèëèîí',
        165 => 'êâàòîðêâèíêàãèíòèëèîí',
        168 => 'êâèíêâèíêàãèíòèëèîí',
        171 => 'ñåêñêâèíêàãèíòèëèîí',
        174 => 'ñåïòåíêâèíêàãèíòèëèîí',
        177 => 'îêòîêâèíêàãèíòèëèîí',
        180 => 'íîâåìêâèíêàãèíòèëèîí',
        183 => 'ñåêñàãèíòèëèîí',
        186 => 'óíñåêñàãèíòèëèîí',
        189 => 'äóîñåêñàãèíòèëèîí',
        192 => 'òðåñåêñàãèíòèëèîí',
        195 => 'êâàòîðñåêñàãèíòèëèîí',
        198 => 'êâèíñåêñàãèíòèëèîí',
        201 => 'ñåêññåêñàãèíòèëèîí',
        204 => 'ñåïòåíñåêñàãèíòèëèîí',
        207 => 'îêòîñåêñàãèíòèëèîí',
        210 => 'íîâåìñåêñàãèíòèëèîí',
        213 => 'ñåïòàãèíòèëèîí',
        216 => 'óíñåïòàãèíòèëèîí',
        219 => 'äóîñåïòàãèíòèëèîí',
        222 => 'òðåñåïòàãèíòèëèîí',
        225 => 'êâàòîðñåïòàãèíòèëèîí',
        228 => 'êâèíñåïòàãèíòèëèîí',
        231 => 'ñåêññåïòàãèíòèëèîí',
        234 => 'ñåïòåíñåïòàãèíòèëèîí',
        237 => 'îêòîñåïòàãèíòèëèîí',
        240 => 'íîâåìñåïòàãèíòèëèîí',
        243 => 'îêòîãèíòèëèîí',
        246 => 'óíîêòîãèíòèëèîí',
        249 => 'äóîîêòîãèíòèëèîí',
        252 => 'òðåîêòîãèíòèëèîí',
        255 => 'êâàòîðîêòîãèíòèëèîí',
        258 => 'êâèíîêòîãèíòèëèîí',
        261 => 'ñåêñîêòîãèíòèëèîí',
        264 => 'ñåïòîêòîãèíòèëèîí',
        267 => 'îêòîîêòîãèíòèëèîí',
        270 => 'íîâåìîêòîãèíòèëèîí',
        273 => 'íîíàãèíòèëèîí',
        276 => 'óííîíàãèíòèëèîí',
        279 => 'äóîíîíàãèíòèëèîí',
        282 => 'òðåíîíàãèíòèëèîí',
        285 => 'êâàòîðíîíàãèíòèëèîí',
        288 => 'êâèííîíàãèíòèëèîí',
        291 => 'ñåêñíîíàãèíòèëèîí',
        294 => 'ñåïòåííîíàãèíòèëèîí',
        297 => 'îêòîíîíàãèíòèëèîí',
        300 => 'íîâåìíîíàãèíòèëèîí',
        303 => 'öåíòèëèîí'
    );
    // }}}

    // {{{ Numbers_Words_bg()

    /**
     * The class constructor, used for calling the _initDigits method.
     *
     * @return void
     *
     * @access public
     * @author Kouber Saparev <kouber@php.net>
     * @see function _initDigits
     */
    function Numbers_Words_bg() {
        $this->_initDigits();
    }
    // }}}

    // {{{ _initDigits()

    /**
     * Fills the _digits array for masculine and feminine genders with
     * corresponding references to neuter words (when they're the same).
     *
     * @return void
     *
     * @access private
     * @author Kouber Saparev <kouber@php.net>
     */
    function _initDigits() {
        if (!$this->_digits_initialized) {
            for ($i=3; $i<=9; $i++) {
                $this->_digits[1][$i] =& $this->_digits[0][$i];
            }
            for ($i=2; $i<=9; $i++) {
                $this->_digits[-1][$i] =& $this->_digits[0][$i];
            }
            $this->_digits_initialized = true;
        }
    }
    // }}}

    // {{{ _splitNumber()

    /**
     * Split a number to groups of three-digit numbers.
     *
     * @param  mixed  $num   An integer or its string representation
     *                       that need to be split
     *
     * @return array  Groups of three-digit numbers.
     *
     * @access private
     * @author Kouber Saparev <kouber@php.net>
     * @since  PHP 4.2.3
     */

    function _splitNumber($num)
    {
        if (is_string($num)) {
            $ret = array();
            $strlen = strlen($num);
            $first = substr($num, 0, $strlen%3);
            preg_match_all('/\d{3}/', substr($num, $strlen%3, $strlen), $m);
            $ret =& $m[0];
            if ($first) array_unshift($ret, $first);
            return $ret;
        }
        else
            return explode(' ', number_format($num, 0, '', ' ')); // a faster version for integers
    }
    // }}}

    // {{{ _showDigitsGroup()

    /**
     * Converts a three-digit number to its word representation
     * in Bulgarian language.
     *
     * @param  integer  $num     An integer between 1 and 999 inclusive.
     *
     * @param  integer  $gender  An integer which represents the gender of
     *                                                     the current digits group.
     *                                                     0 - neuter
     *                                                     1 - masculine
     *                                                    -1 - feminine
     *
     * @param  boolean  $last    A flag that determines if the current digits group
     *                           is the last one.
     *
     * @return string   The words for the given number.
     *
     * @access private
     * @author Kouber Saparev <kouber@php.net>
     */
    function _showDigitsGroup($num, $gender = 0, $last = false)
    {
        /* A storage array for the return string.
             Positions 1, 3, 5 are intended for digit words
             and everything else (0, 2, 4) for "and" words.
             Both of the above types are optional, so the size of
             the array may vary.
        */
        $ret = array();
        
        // extract the value of each digit from the three-digit number
        $e = $num%10;                  // ones
        $d = ($num-$e)%100/10;         // tens
        $s = ($num-$d*10-$e)%1000/100; // hundreds
        
        // process the "hundreds" digit.
        if ($s) {
            switch ($s) {
                case 1:
                    $ret[1] = $this->_misc_strings['sto'];
                    break;
                case 2:
                case 3:
                    $ret[1] = $this->_digits[0][$s].$this->_misc_strings['sta'];
                    break;
             default:
                 $ret[1] = $this->_digits[0][$s].$this->_misc_strings['stotin'];
            }
        }

        // process the "tens" digit, and optionally the "ones" digit.
        if ($d) {
            // in the case of 1, the "ones" digit also must be processed
            if ($d==1) {
                if (!$e) {
                    $ret[3] = $this->_misc_strings['deset']; // ten
                } else {
                    if ($e==1) {
                        $ret[3] = $this->_misc_strings['edinadeset']; // eleven
                    } else {
                        $ret[3] = $this->_digits[1][$e].$this->_misc_strings['na'].$this->_misc_strings['deset']; // twelve - nineteen
                    }
                    // the "ones" digit is alredy processed, so skip a second processment
                    $e = 0;
                }
            } else {
                $ret[3] = $this->_digits[1][$d].$this->_misc_strings['deset']; // twenty - ninety
            }
        }

        // process the "ones" digit
        if ($e) {
            $ret[5] = $this->_digits[$gender][$e];
        }

        // put "and" where needed
        if (count($ret)>1) {
            if ($e) {
                $ret[4] = $this->_and;
            } else {
                $ret[2] = $this->_and;
            }
        }

        // put "and" optionally in the case this is the last non-empty group
        if ($last) {
            if (!$s||count($ret)==1) {
                $ret[0] = $this->_and;
            }
            $this->_last_and = true;
        }

        // sort the return array so that "and" constructs go to theirs appropriate places
        ksort($ret);

        return implode($this->_sep, $ret);
    }
    // }}}

    // {{{ toWords()

    /**
     * Converts a number to its word representation
     * in Bulgarian language.
     *
     * @param  integer $num   An integer between 9.99*-10^302 and 9.99*10^302 (999 centillions)
     *                        that need to be converted to words
     *
     * @return string  The corresponding word representation
     *
     * @access public
     * @author Kouber Saparev <kouber@php.net>
     */
    function toWords($num = 0)
    {
        $ret = array();
        $ret_minus = '';

        // check if $num is a valid non-zero number
        if (!$num || preg_match('/^-?0+$/', $num) || !preg_match('/^-?\d+$/', $num)) return $this->_zero;

        // add a minus sign
        if (substr($num, 0, 1) == '-') {
            $ret_minus = $this->_minus . $this->_sep;
            $num = substr($num, 1);
        }

        // if the absolute value is greater than 9.99*10^302, return infinity
        if (strlen($num)>306) {
            return $ret_minus . $this->_infinity;
        }

        // strip excessive zero signs
        $num = ltrim($num, '0');

        // split $num to groups of three-digit numbers
        $num_groups = $this->_splitNumber($num);

        $sizeof_numgroups = count($num_groups);

        // go through the groups in reverse order, so that the last group could be determined
        for ($i=$sizeof_numgroups-1, $j=1; $i>=0; $i--, $j++) {
            if (!isset($ret[$j])) {
                $ret[$j] = '';
            }

            // what is the corresponding exponent for the current group
            $pow = $sizeof_numgroups-$i;

            // skip processment for empty groups
            if ($num_groups[$i]!='000') {
                if ($num_groups[$i]>1) {
                    if ($pow==1) {
                        $ret[$j] .= $this->_showDigitsGroup($num_groups[$i], 0, !$this->_last_and && $i).$this->_sep;
                        $ret[$j] .= $this->_exponent[($pow-1)*3];
                    } elseif ($pow==2) {
                        $ret[$j] .= $this->_showDigitsGroup($num_groups[$i], -1, !$this->_last_and && $i).$this->_sep;
                        $ret[$j] .= $this->_misc_strings['hiliadi'].$this->_sep;
                    } else {
                        $ret[$j] .= $this->_showDigitsGroup($num_groups[$i], 1, !$this->_last_and && $i).$this->_sep;
                        $ret[$j] .= $this->_exponent[($pow-1)*3].$this->_plural.$this->_sep;
                    }
                } else {
                    if ($pow==1) {
                        $ret[$j] .= $this->_showDigitsGroup($num_groups[$i], 0, !$this->_last_and && $i).$this->_sep;
                    } elseif ($pow==2) {
                        $ret[$j] .= $this->_exponent[($pow-1)*3].$this->_sep;
                    } else {
                        $ret[$j] .= $this->_digits[1][1].$this->_sep.$this->_exponent[($pow-1)*3].$this->_sep;
                    }
                }
            }
        }

        return $ret_minus . rtrim(implode('', array_reverse($ret)), $this->_sep);
    }
    // }}}
}
?>
