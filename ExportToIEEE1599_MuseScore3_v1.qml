import QtQuick 2.9
import QtQuick.Controls 1.4
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import Qt.labs.settings 1.0
// FileDialog
import Qt.labs.folderlistmodel 2.2
import QtQml 2.8
import MuseScore 3.0
import FileIO 3.0

MuseScore {
	menuPath: "Plugins." + "Export to IEEE 1599"
	version: "3.0"
	description: "Export to IEEE 1599 format..."
	pluginType: "dialog"
	id: window
	width: 800
	height: 600

	property int smallSpace: 10
	property int bigSpace: 100
	property int buttonWidth: 80
	property int smallWidth: 150
	property int mediumWidth: 300
	property int bigWidth: 500
	property int stdHeight: 24
	property int bigHeight: 45
	property int fontTitleSize: 16
	property int fontSize: 12

	property string crlf: "\r\n"
	property string strSTAFF: "staff"
	property string strMEASURE: "meas"
	property string strVOICE: "voice"
	property string strEVENT: "ev"
	property string strCLEF: "clef"
	property string strKEYSIG: "keysig"
	property string strTIMESIG: "timesig"

	property int vtuPerQuarter: division
	property
	var arrMeasures: []
	property
	var dictSpine: []
	property
	var dictParts: []
	property
	var dictStaves: []
	property
	var dictLyrics: []
	property
	var dictBBoxesMapChords: []
	property
	var dictBBoxesMapNotes: []

	onRun: {
		calculateMeasures()
		calculateEventDictionaries()
		// check MuseScore version
		if (!(mscoreMajorVersion > 1 && (mscoreMinorVersion > 0 || mscoreUpdateVersion > 0)))
			errorDialog.openErrorDialog(qsTr("Minimum MuseScore Version %1 required for export").arg("2.0.1"))
		if (!(curScore)) {
			errorDialog.openErrorDialog(qsTranslate("QMessageBox", "No score available.\nThis plugin requires an open score to run.\n"))
			Qt.quit()
		}
                //textFieldFilePath.text = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation)
	}

	Component.onDestruction: {
		settings.exportDirectory = exportDirectory.text
	}

	FileIO {
		id: xmlWriter
		onError: console.log(msg + "  Filename = " + xmlWriter.source)
	}

	MessageDialog {
		id: errorDialog
		visible: false
		title: qsTr("Error")
		text: "Error"
		onAccepted: {
			close()
		}

		function openErrorDialog(message) {
			text = message
			open()
		}
	}

	MessageDialog {
		id: endDialog
		visible: false
		title: qsTr("Conversion performed")
		text: "Score has been successfully converted to IEEE 1599 format." + crlf + "Resulting file: " + textFieldFilePath.text + "/" + textFieldFileName.text + crlf + crlf
		onAccepted: {
			Qt.quit()
		}

		function openEndDialog(message) {
			text = message
			open()
		}
	}

	FileDialog {
		id: directorySelectDialog
		title: qsTr("Please choose a directory")
		selectFolder: true
		visible: false
		onAccepted: {
			var exportDirectory = this.folder.toString().replace("file://", "").replace(/^\/(.:\/)(.*)$/, "$1$2")
			console.log("Selected directory: " + exportDirectory)
			textFieldFilePath.text = exportDirectory
			close()
		}
		onRejected: {
			console.log("Directory not selected")
			close()
		}
	}

	// Step 1: create XML
	function createXML() {

		if (!textFieldFileName.text) {
			errorDialog.openErrorDialog(qsTr("File name not specified"))
			return
		} else if (!textFieldFilePath.text) {
			errorDialog.openErrorDialog(qsTr("File folder not specified"))
			return
		}

		var xml = "<?xml version='1.0' encoding='UTF-8'?>" + crlf
		xml += createDocType()
		xml += "<ieee1599 version='1.0' creator='MuseScore Export Plugin " + version + "'>" + crlf
		xml += createGeneral()
		xml += createLogic()
		if (checkEnableExport.checked)
			xml += createNotational()
		xml += "</ieee1599>"
		// console.log("Resulting XML:" + crlf + xml)
		var filename = textFieldFilePath.text + "/" + textFieldFileName.text
		console.log("Export to " + filename)
		xmlWriter.source = filename
		console.log("Writing XML...")
		xmlWriter.write(xml)
		console.log("Conversion performed")
		endDialog.open()
	}

	// Step 1.1: DOCTYPE
	function createDocType() {
		var crlf = "\r\n"
		var result = "<!DOCTYPE ieee1599 SYSTEM 'http://www.lim.di.unimi.it/IEEE/ieee1599.dtd'>" + crlf
		return result
	}

	// Step 1.2: create General
	function createGeneral() {
		console.log("Compiling the General layer...")
		var result = indent(1) + "<general>" + crlf
		result += indent(2) + "<description>" + crlf
		result += indent(3) + "<main_title>"
		result += unescape(encodeURIComponent(textFieldTitle.text))
		// console.log("General > title: " + unescape(encodeURIComponent(curScore.title)))
		result += "</main_title>" + crlf
		result += indent(3) + "<author type=\"composer\">"
		result += unescape(encodeURIComponent(textFieldAuthorMusic.text))
		// console.log("General > author[composer]: " + unescape(encodeURIComponent(curScore.composer)))
		result += "</author>" + crlf
		if (textFieldAuthorLyrics.text) {
			result += indent(3) + "<author type=\"poet\">"
			result += unescape(encodeURIComponent(textFieldAuthorLyrics.text))
			// console.log("General > author[poet]: " + unescape(encodeURIComponent(curScore.poet)))
			result += "</author>" + crlf
		}
		if (textFieldNumber.text) {
			result += indent(3) + "<number>"
			result += unescape(encodeURIComponent(textFieldNumber.text))
			result += "</number>" + crlf
		}
		if (textFieldWorkTitle.text) {
			result += indent(3) + "<work_title>"
			result += unescape(encodeURIComponent(textFieldWorkTitle.text))
			result += "</work_title>" + crlf
		}
		if (textFieldWorkNumber.text) {
			result += indent(3) + "<work_number>"
			result += unescape(encodeURIComponent(textFieldWorkNumber.text))
			result += "</work_number>" + crlf
		}
		result += indent(2) + "</description>" + crlf
		result += indent(1) + "</general>" + crlf
		return result
	}

	// Step 1.3: create Logic
	function createLogic() {
		console.log("Compiling the Logic layer...")
		var result = indent(1) + "<logic>" + crlf
		result += createSpine()
		result += createLOS()
		result += indent(1) + "</logic>" + crlf
		return result
	}

	// Step 1.3.1: create Spine
	function createSpine() {
		console.log("Creating the spine...")
		var result = indent(2) + "<spine>" + crlf
		var oldVtu = 0
		for (var currentTick in dictSpine) {
			for (var staffIdx in dictStaves) {
				if (dictStaves[staffIdx][2][currentTick]) {
					var id = dictStaves[staffIdx][2][currentTick].split(";;")[0]
					result += indent(3) + "<event id=\"" + id + "\" timing=\"" + (currentTick - oldVtu) + "\" hpos=\"" + (currentTick - oldVtu) + "\" />" + crlf
					oldVtu = currentTick
				}
				if (dictStaves[staffIdx][3][currentTick]) {
					var id = dictStaves[staffIdx][3][currentTick].split(";;")[0]
					result += indent(3) + "<event id=\"" + id + "\" timing=\"" + (currentTick - oldVtu) + "\" hpos=\"" + (currentTick - oldVtu) + "\" />" + crlf
					oldVtu = currentTick
				}
				if (dictStaves[staffIdx][4][currentTick]) {
					var id = dictStaves[staffIdx][4][currentTick].split(";;")[0]
					result += indent(3) + "<event id=\"" + id + "\" timing=\"" + (currentTick - oldVtu) + "\" hpos=\"" + (currentTick - oldVtu) + "\" />" + crlf
					oldVtu = currentTick
				}
			}
			for (var i = 0; i < dictSpine[currentTick].length; i++) {
				if (i == 0)
					result += indent(3) + "<event id=\"" + dictSpine[currentTick][i] + "\" timing=\"" + (currentTick - oldVtu) + "\" hpos=\"" + (currentTick - oldVtu) + "\" />" + crlf
				else
					result += indent(3) + "<event id=\"" + dictSpine[currentTick][i] + "\" timing=\"0\" hpos=\"0\" />" + crlf
				oldVtu = currentTick
			}
		}
		result += indent(2) + "</spine>" + crlf
		return result
	}

	// Step 1.3.2: create LOS
	function createLOS() {
		console.log("Creating logically organized symbols...")

		var parts = ""
		var lyrics = ""

		// Parts
		for (var partIdx = 0; partIdx < curScore.parts.length; partIdx++) {
			var partVoices = []
			var currentPartName = getPartNameFromPartIndex(partIdx)
			parts += indent(3) + "<part id=\"" + currentPartName + "\"" + getPartTransposition(partIdx) + ">" + crlf

			// Measures
			var measures = ""
			for (var measNum in dictParts[currentPartName]) {
				measures += indent(4) + "<measure number=\"" + measNum + "\">" + crlf
				for (var voiceId in dictParts[currentPartName][measNum]) {

					// Voice List
					if (partVoices.indexOf(voiceId) == -1)
						partVoices.push(voiceId)

					measures += indent(5) + "<voice voice_item_ref=\"" + voiceId + "\">" + crlf
					for (var chordOrRestIdx in dictParts[currentPartName][measNum][voiceId]) {
						var chordOrRest = dictParts[currentPartName][measNum][voiceId][chordOrRestIdx]
						var splitted = chordOrRest.split(";;")
						var id = splitted[1]
						var num = splitted[2].split(";")[0]
						var den = splitted[2].split(";")[1]
						var augDots = splitted[2].split(";")[2]
						var tuplet = splitted[2].split(";")[3]
						var notes = splitted[3]
						if (tuplet != ",,,") {
							var tupletEnterNum = tuplet.split(",")[0]
							var tupletEnterDen = tuplet.split(",")[1]
							var tupletInNum = tuplet.split(",")[2]
							var tupletInDen = tuplet.split(",")[3]
						}
						if (splitted[0] == "C") { // Chord
							measures += indent(6) + "<chord event_ref=\"" + id + "\" >" + crlf
							measures += indent(7) + "<duration num=\"" + num + "\" den=\"" + den + "\" >" + crlf
							if (tuplet != ",,,")
								measures += indent(8) + "<tuplet_ratio enter_num=\"" + tupletEnterNum + "\" enter_den=\"" + tupletEnterDen + "\" in_num=\"" + tupletInNum + "\" in_den=\"" + tupletInDen + "\" />" + crlf
							measures += indent(7) + "</duration>" + crlf
							if (augDots != "0")
								measures += indent(7) + "<augmentation_dots number=\"" + augDots + "\" />" + crlf
							var splittedNotes = notes.split(";")
							for (var noteIdx in splittedNotes) {
								var note = splittedNotes[noteIdx]
								var step = note.split(",")[0]
								if (step == "")
									continue
								var octave = note.split(",")[1]
								var actualAccidental = note.split(",")[2]
								var printedAccidental = note.split(",")[3]
								var tie = note.split(",")[4]
								measures += indent(7) + "<notehead>" + crlf
								measures += indent(8) + "<pitch step=\"" + step + "\" octave=\"" + octave + "\" actual_accidental=\"" + actualAccidental + "\"/>" + crlf
								if (printedAccidental)
									measures += indent(8) + "<printed_accidentals><" + printedAccidental + " /></printed_accidentals>" + crlf
								if (tie)
									measures += indent(8) + "<tie />" + crlf
								measures += indent(7) + "</notehead>" + crlf
							}
							measures += indent(6) + "</chord>" + crlf
						} else { // Rest
							measures += indent(6) + "<rest event_ref=\"" + id + "\" >" + crlf
							measures += indent(7) + "<duration num=\"" + num + "\" den=\"" + den + "\" >" + crlf
							if (tuplet != ",,,")
								measures += indent(8) + "<tuplet_ratio enter_num=\"" + tupletEnterNum + "\" enter_den=\"" + tupletEnterDen + "\" in_num=\"" + tupletInNum + "\" in_den=\"" + tupletInDen + "\" />" + crlf
							measures += indent(7) + "</duration>" + crlf
							if (augDots != "0")
								measures += indent(7) + "<augmentation_dots number=\"" + augDots + "\" />" + crlf
							measures += indent(6) + "</rest>" + crlf
						}
					}
					measures += indent(5) + "</voice>" + crlf
				}
				measures += indent(4) + "</measure>" + crlf
			}

			// Voice list (for parts)
			parts += indent(4) + "<voice_list>" + crlf
			for (var voiceId in partVoices) {
				var id = partVoices[voiceId]
				var staffRef = ""
				for (var staffIdx in dictStaves) {
					for (var v in dictStaves[staffIdx][1])
						if (dictStaves[staffIdx][0] == partIdx && dictStaves[staffIdx][1][v] == id) {
							staffRef = parseInt(staffIdx) + 1
							break
						}
				}
				parts += indent(5) + "<voice_item id=\"" + id + "\" staff_ref=\"staff" + staffRef + "\" />" + crlf
			}

			parts += indent(4) + "</voice_list>" + crlf

			parts += measures
			parts += indent(3) + "</part>" + crlf
		}

		if (lyrics != "")
			parts += lyrics + indent(3) + "</lyrics>" + crlf

		// Staff list
		var staffList = indent(3) + "<staff_list>" + crlf
		for (var staffIdx in dictStaves) {
			var staffRef = parseInt(staffIdx) + 1
			staffList += indent(4) + "<staff id=\"staff" + staffRef + "\">" + crlf
			for (var tick in dictStaves[staffIdx][2]) {
				var splitted = dictStaves[staffIdx][2][tick].split(";;")
				var eventRef = splitted[0]
				var shape = splitted[1]
				var staffStep = splitted[2]
				staffList += indent(5) + "<clef event_ref=\"" + eventRef + "\" shape=\"" + shape + "\" staff_step=\"" + staffStep + "\"/>" + crlf
			}
			for (var tick in dictStaves[staffIdx][3]) {
				var splitted = dictStaves[staffIdx][3][tick].split(";;")
				var eventRef = splitted[0]
				var k = parseInt(splitted[1])
				staffList += indent(5) + "<key_signature event_ref=\"" + eventRef + "\">" + crlf
				if (k >= 0)
					staffList += indent(6) + "<sharp_num number=\"" + k + "\"/>" + crlf
				else
					staffList += indent(6) + "<flat_num number=\"" + (-1 * k) + "\"/>" + crlf
				staffList += indent(5) + "</key_signature>" + crlf
			}
			for (var tick in dictStaves[staffIdx][4]) {
				var splitted = dictStaves[staffIdx][4][tick].split(";;")
				var eventRef = splitted[0]
				var num = parseInt(splitted[1])
				var den = parseInt(splitted[2])
				var numS = splitted[3]
				var denS = splitted[4]
				var vtuAmount = 4 * 480 * num / den
				staffList += indent(5) + "<time_signature event_ref=\"" + eventRef + "\">" + crlf
				if (numS == "C" || numS == "¢")
					staffList += indent(6) + "<time_indication num=\"" + num + "\" den=\"" + den + "\" abbreviation=\"yes\" vtu_amount=\"" + vtuAmount + "\" />" + crlf
				else if (denS == "")
					staffList += indent(6) + "<time_indication num=\"" + numS + "\" vtu_amount=\"" + vtuAmount + "\" />" + crlf
				else
					staffList += indent(6) + "<time_indication num=\"" + numS + "\" den=\"" + denS + "\" vtu_amount=\"" + vtuAmount + "\" />" + crlf
				staffList += indent(5) + "</time_signature>" + crlf
			}
			staffList += indent(4) + "</staff>" + crlf
		}

		staffList += indent(3) + "</staff_list>" + crlf

		var result = indent(2) + "<los>" + crlf
		result += staffList + parts

		// Lyrics
		for (var lyricsBlock in dictLyrics)
			if (dictLyrics[lyricsBlock] != "") {
				var splitted = lyricsBlock.split(";")
				var partRef = splitted[0]
				var voiceRef = splitted[1]
				result += indent(3) + "<lyrics part_ref=\"" + partRef + "\" voice_ref=\"" + voiceRef + "\">" + crlf
				result += dictLyrics[lyricsBlock]
				result += indent(3) + "</lyrics>" + crlf
			}
		result += indent(2) + "</los>" + crlf
		return result
	}

	// Step 1.4: create Notational
	function createNotational() {

		var dictBBoxes;

		if (radioButtonChords.checked)
			dictBBoxes = dictBBoxesMapChords
		else
			dictBBoxes = dictBBoxesMapNotes

		console.log("Creating notational...")
		var spatium = 0.0694
		if (textFieldDistance.text != "1.764")
			spatium = parseFloat(textFieldDistance.text) / 25.4
		console.log("Spatium: " + spatium)
		var dpi = 300
		if (textFieldDPI.text)
			dpi = Math.round(parseFloat(textFieldDPI.text))
		console.log("DPI: " + dpi)
		var result = indent(1) + "<notational>" + crlf
		result += indent(2) + "<graphic_instance_group description=\"" + textFieldGraphicalGroupDesc.text + "\">" + crlf
		for (var pageNumber in dictBBoxes) {
			result += indent(3) + "<graphic_instance position_in_group=\"" + pageNumber + "\" file_name=\"" + curScore.title + "-" + pageNumber + ".png\""
			result += " file_format=\"image_png\" encoding_format=\"image_png\" measurement_unit=\"pixels\">" + crlf

			for (var eventId in dictBBoxes[pageNumber]) {
				var splittedMain = dictBBoxes[pageNumber][eventId].split(";;")

				for (var noteIndex = 1; noteIndex < splittedMain.length; noteIndex++) {
					var splitted = splittedMain[noteIndex].split(";")

					var upperLeftX = Math.round(parseFloat(splitted[0]) * spatium * dpi)
					var upperLeftY = Math.round(parseFloat(splitted[1]) * spatium * dpi)

					var lowerRightX = Math.round((parseFloat(splitted[0]) + parseFloat(splitted[2])) * spatium * dpi)
					var lowerRightY = Math.round((parseFloat(splitted[1]) + parseFloat(splitted[3])) * spatium * dpi)

					var bbx = Math.round(parseFloat(splitted[4]) * spatium * dpi)
					var bby = Math.round(parseFloat(splitted[5]) * spatium * dpi)

					if (splittedMain[0] == "C") {
						upperLeftX = upperLeftX - 42 + bbx
						lowerRightX = lowerRightX - 42 + bbx
					}
					upperLeftY += bby
					lowerRightY += bby

					upperLeftX -= 5
					upperLeftY -= 5
					lowerRightX += 5
					lowerRightY += 5

					result += indent(4) + "<graphic_event event_ref=\"" + eventId + "\" upper_left_x=\"" + upperLeftX + "\" upper_left_y=\"" + upperLeftY + "\""
					result += " lower_right_x=\"" + lowerRightX + "\" lower_right_y=\"" + lowerRightY + "\" />" + crlf

				}

			}

			result += indent(3) + "</graphic_instance>" + crlf
		}
		result += indent(2) + "</graphic_instance_group>" + crlf
		result += indent(1) + "</notational>" + crlf
		return result
	}

	function filenameFromScore() {
		var name = curScore.title
		name = name.replace(/ /g, "_").toLowerCase()
		return name
	}

	function zeroPad(num, places) {
		var zero = places - num.toString().length + 1
		return Array(+(zero > 0 && zero)).join("0") + num
	}

	function getPartNameFromPartIndex(idx) {
		var candidatePartName = curScore.parts[idx].longName.toLowerCase().replace(/ /g, "_").replace(/[^a-zA-Z0-9_]+/g, "")
		if (candidatePartName == null || candidatePartName == "")
			candidatePartName = "part"
		return candidatePartName + (parseInt(idx) + 1)
	}

	function getRealTrackIdxsOfPart(partIdx) {
		var trackIdxs = []
		var tempCursor = curScore.newCursor()
		var startTrack = curScore.parts[partIdx].startTrack
		var endTrack = curScore.parts[partIdx].endTrack
		for (var j = startTrack; j < endTrack; j++) { // Note that endTrack is excluded!
			tempCursor.track = j
			tempCursor.rewind(0)
			while (tempCursor.next())
				if (tempCursor.element != null && (tempCursor.element.type == Element.CHORD || tempCursor.element.type == Element.REST)) {
					trackIdxs.push(j)
					break
				}
		}
		return trackIdxs
	}

	function getPartTransposition(idx) {
		var tempCursor = curScore.newCursor()
		var startTrack = curScore.parts[idx].startTrack
		var endTrack = curScore.parts[idx].endTrack
		var delta = 0
		var deltaCalculated = false
		for (var j = startTrack; j < endTrack; j++) { // Note that endTrack is excluded!
			tempCursor.track = j
			tempCursor.rewind(0)
			do {
				if (tempCursor.element != null && tempCursor.element.type == Element.CHORD) {
					delta = tempCursor.element.notes[0].tpc2 - tempCursor.element.notes[0].tpc1
					deltaCalculated = true
					break
				}
			}
			while (tempCursor.next())
			if (deltaCalculated)
				break
		}
		if (delta == 0)
			return ""
		// else: transposing instrument
		var transpositionString = ""
		var transpositionNote = 14 - delta // the amount to bring C natural to the transposing key 
		switch (transpositionNote) {
			case 13:
				transpositionString = " transposition_pitch='F' transposition_accidental= 'none'"
				break
			case 12:
				transpositionString = " transposition_pitch='B' transposition_accidental= 'flat'"
				break
			case 11:
				transpositionString = " transposition_pitch='E' transposition_accidental= 'flat'"
				break
			case 10:
				transpositionString = " transposition_pitch='A' transposition_accidental= 'flat'"
				break
			case 9:
				transpositionString = " transposition_pitch='D' transposition_accidental= 'flat'"
				break
			case 8:
				transpositionString = " transposition_pitch='G' transposition_accidental= 'flat'"
				break
			case 7:
				transpositionString = " transposition_pitch='C' transposition_accidental= 'flat'"
				break
			case 15:
				transpositionString = " transposition_pitch='G' transposition_accidental= 'none'"
				break
			case 16:
				transpositionString = " transposition_pitch='D' transposition_accidental= 'none'"
				break
			case 17:
				transpositionString = " transposition_pitch='A' transposition_accidental= 'none'"
				break
			case 18:
				transpositionString = " transposition_pitch='E' transposition_accidental= 'none'"
				break
			case 19:
				transpositionString = " transposition_pitch='B' transposition_accidental= 'none'"
				break
			case 20:
				transpositionString = " transposition_pitch='F' transposition_accidental= 'sharp'"
				break
			case 21:
				transpositionString = " transposition_pitch='C' transposition_accidental= 'sharp'"
				break
		}
		return transpositionString
	}

	function getStep(note) {
		var step = "none"
		switch (note.tpc % 7) {
			case 0:
				step = "C"
				break
			case 1:
				step = "G"
				break
			case 2:
				step = "D"
				break
			case 3:
				step = "A"
				break
			case 4:
				step = "E"
				break
			case 5:
				step = "B"
				break
			case 6:
				step = "F"
				break
			default:
				step = "none"
		}
		return step
	}

	function getOctave(note) {
		var octave = note.pitch / 12
		if (note.tpc == 0 || note.tpc == 7)
			octave++
			if (note.tpc == 26 || note.tpc == 33)
				octave--
				return Math.floor(octave)
	}

	function getActualAccidental(note) {
		var accidental = "none"
		if (note.tpc <= 5)
			accidental = "double_flat"
		else if (note.tpc <= 12)
			accidental = "flat"
		else if (note.tpc <= 19)
			accidental = "natural"
		else if (note.tpc <= 26)
			accidental = "sharp"
		else
			accidental = "double_sharp"
		return accidental
	}


	// Accidentals: none | double_flat | flat | natural | sharp | double_sharp | double_flat | flat_and_a_half | flat | demiflat | natural | demisharp | sharp | sharp_and_a_half | double_sharp
	function getPrintedAccidentals(note) {
		var accidental = ""
		switch (note.accidentalType) {
			case Accidental.SHARP_ARROW_DOWN:
			case Accidental.SHARP_SLASH:
			case Accidental.NATURAL_ARROW_UP:
			case Accidental.SORI:
				accidental += "demisharp"
				break
			case Accidental.SHARP:
				accidental += "sharp"
				break
			case Accidental.SHARP_ARROW_UP:
			case Accidental.SHARP_SLASH4:
				accidental += "sharp_and_a_half"
				break
			case Accidental.SHARP2:
				accidental += "double_sharp"
				break
			case Accidental.FLAT_ARROW_UP:
			case Accidental.MIRRORED_FLAT:
			case Accidental.NATURAL_ARROW_DOWN:
			case Accidental.KORON:
				accidental += "demiflat"
				break
			case Accidental.FLAT:
				accidental += "flat"
				break
			case Accidental.FLAT_ARROW_DOWN:
			case Accidental.MIRRORED_FLAT2:
				accidental += "flat_and_a_half"
				break
			case Accidental.FLAT2:
				accidental += "double_flat "
				break
			case Accidental.NATURAL:
				accidental += "natural"
				break
		}
		if (note.accidental.hasBracket)
			accidental += "-bracketed"
		else if (note.accidental.small)
			accidental += "-small"
console.log(">>>" + (note.accidentalType*1 + 1))
console.log(">>>" + (Accidental.SHARP*1 + 1))
if ((note.accidentalType*1 + 1) == (Accidental.SHARP*1 + 1))
		return accidental
	}

	function parseLyrics(chord, eventId) {
		var result = ""
		for (var i = 0; i < chord.lyrics.length; i++) {
			result += indent(4) + "<syllable start_event_ref='" + eventId + "'"

			if (chord.lyrics[i].syllabic === Lyrics.SINGLE || chord.lyrics[i].syllabic === Lyrics.END) {
				result += " hyphen='no'"
			} else {
				result += " hyphen='yes'"
			}
			result += ">"
			result += unescape(encodeURIComponent(chord.lyrics[i].text))
			result += "</syllable>" + crlf
		}
		return result
	}

	function getClef(staffIdx) {
		var tempCursor = curScore.newCursor()
		tempCursor.staffIdx = staffIdx
		tempCursor.rewind(0)
		if (tempCursor.element == null)
			return "G_2"
		do {
			if (tempCursor.element.type == Element.CHORD) {
				// use a single note comparing its tonal pitch class and the line/space where it is written in order to infer the clef
				var note = tempCursor.element.notes[0]
				var tonalPitchClass = ((note.tpc2 % 7) + ((note.tpc2 % 7) % 2) * 7) / 2
				var position = (note.pos * 2) % 7

				switch (tonalPitchClass + position) {
					case 0:
						return "F_4"
					case 2:
						return "C_6"
					case 4:
						return "C_4"
					case 5:
						return "F_6"
					case 6:
						return "C_2"
					case 8:
						return "C_0"
					case 10:
					default:
						return "G_2"
				}
			}
		}
		while (tempCursor.next())
		return "G_2"
	}

	function getEventId(partName, measNum, voiceNum, eventNum) {
		var candidateId = partName + "_" + strMEASURE + measNum + "_" + strVOICE + voiceNum + "_" + strEVENT + eventNum
		return candidateId
	}

	function getClefId(staffNum, measNum, deltaTick) {
		var candidateId = strCLEF + "_" + strSTAFF + staffNum + "_" + strMEASURE + measNum + "_" + deltaTick
		return candidateId
	}

	function getKeySignId(staffNum, measNum) {
		var candidateId = strKEYSIG + "_" + strSTAFF + staffNum + "_" + strMEASURE + measNum
		return candidateId
	}

	function getTimeSignId(staffNum, measNum) {
		var candidateId = strTIMESIG + "_" + strSTAFF + staffNum + "_" + strMEASURE + measNum
		return candidateId
	}

	function calculateMeasures() {
		var cursor = curScore.newCursor()
		for (var trackIdx = 0; trackIdx < curScore.ntracks; trackIdx++) {
			cursor.track = trackIdx
			cursor.rewind(0)
			while (cursor.segment) {
				if (arrMeasures.indexOf(cursor.tick) == -1)
					arrMeasures.push(cursor.tick)
				cursor.nextMeasure()
			}
		}
		arrMeasures.sort(function(a, b) {
			return a - b
		})
	}

	function calculateEventDictionaries() {
		var cursor = curScore.newCursor()
		for (var partIdx = 0; partIdx < curScore.parts.length; partIdx++) {
			var partName = getPartNameFromPartIndex(partIdx)
			dictParts[partName] = []
			var arrVoices = getRealTrackIdxsOfPart(partIdx)
			for (var voice = 0; voice < arrVoices.length; voice++) {
				var oldClef = null
				var oldKeySign = null
				var oldTimeSign = null
				var voiceId = partName + "_" + strVOICE + (voice + 1)
				dictLyrics[partName + ";" + voiceId] = ""
				var staffIdx = Math.floor(arrVoices[voice] / 4)
				if (dictStaves[staffIdx] == null) {
					dictStaves[staffIdx] = []
					dictStaves[staffIdx].push(partIdx) // part
					dictStaves[staffIdx].push([]) // voice
					dictStaves[staffIdx].push([]) // clef
					dictStaves[staffIdx].push([]) // key_signature
					dictStaves[staffIdx].push([]) // time_signature
				}
				dictStaves[staffIdx][1].push(voiceId) // voice
				var eventNum = 1
				var oldMeasNum = -1
				var sequence = []
				cursor.track = arrVoices[voice]
				cursor.rewind(0)
				do {
					if (cursor.element != null && (cursor.element.type == Element.CHORD || cursor.element.type == Element.REST)) {
						var measNum = 0
						while (arrMeasures.length > measNum + 1 && arrMeasures[measNum + 1] <= cursor.tick)
							measNum++
							if (measNum >= arrMeasures.length)
								measNum--
								if (measNum > oldMeasNum) {
									eventNum = 1
									sequence = []
								}
						oldMeasNum = measNum;

						// add current measure to part dictionary
						if (dictParts[partName][measNum + 1] == null)
							dictParts[partName][measNum + 1] = []
						// add current voice to part dictionary
						if (dictParts[partName][measNum + 1][voiceId] == null)
							dictParts[partName][measNum + 1][voiceId] = []

						// Clef
						if (cursor.element.type == Element.CHORD) {
							var clef = ""
							if (curScore.parts[partIdx].hasPitchedStaff) {
								var note = cursor.element.notes[0]
								var tonalPitchClass = ((note.tpc2 % 7) + ((note.tpc2 % 7) % 2) * 7) / 2
								var position = (note.posY * 2) % 7
								var sum = parseInt(tonalPitchClass + position + 7) % 7
								switch (sum) {
									case 3:
										clef = "G;;2"
										break
									case 5:
										clef = "F;;6"
										break
									case 0:
										clef = "F;;4"
										break
									case 1:
										clef = "C;;0"
										break
									case 2:
										clef = "C;;6"
										break
									case 4:
										clef = "C;;4"
										break
									case 6:
										clef = "C;;2"
										break
								}
							} else {
								clef = "percussion;;0"
							}
							if (clef != oldClef) {
								var currentTick = cursor.tick
								if (oldClef == null)
									currentTick = 0 // place the first key signature at the very beginning, even if the voice starts later
								if (dictStaves[staffIdx][2][currentTick] == null) {
									dictStaves[staffIdx][2][currentTick] = getClefId(staffIdx + 1, measNum + 1, cursor.tick - arrMeasures[measNum]) + ";;" + clef
									oldClef = clef
								}
							}
						}

						// Key Signature
						if (cursor.keySignature != oldKeySign) {
							var currentTick = cursor.tick
							if (oldKeySign == null)
								currentTick = 0 // place the first key signature at the very beginning, even if the voice starts later
							if (dictStaves[staffIdx][3][currentTick] == null) {
								dictStaves[staffIdx][3][currentTick] = getKeySignId(staffIdx + 1, measNum + 1) + ";;" + cursor.keySignature
								oldKeySign = cursor.keySignature
							}
						}

						// Time Signature
						if (cursor.timeSignature != oldTimeSign) {
							var currentTick = cursor.tick
							if (oldTimeSign == null)
								currentTick = 0 // place the first key signature at the very beginning, even if the voice starts later
							if (dictStaves[staffIdx][4][currentTick] == null) {
								dictStaves[staffIdx][4][currentTick] = getTimeSignId(staffIdx + 1, measNum + 1) + ";;" +
									cursor.timeSignature.numerator + ";;" + cursor.timeSignature.denominator + ";;" +
									cursor.timeSignature.numeratorString + ";;" + cursor.timeSignature.denominatorString
								oldTimeSign = cursor.timeSignature
							}
						}

						// Spine
						var eventId = getEventId(partName, measNum + 1, voice + 1, eventNum)
						if (dictSpine[cursor.tick] == null)
							dictSpine[cursor.tick] = []
						dictSpine[cursor.tick].push(eventId)
						eventNum++

						// BBox
						var pageNumber = cursor.measure.parent.parent.pagenumber + 1
						// --- mapping of rests or complete chords
						var x = cursor.element.posX.toPrecision(6)
						var y = cursor.element.posY.toPrecision(6)
						var w = cursor.element.bbox.width.toPrecision(6)
						var h = cursor.element.bbox.height.toPrecision(6)
						var bbx = cursor.element.bbox.x.toPrecision(6)
						var bby = cursor.element.bbox.y.toPrecision(6)
						if (dictBBoxesMapChords[pageNumber] == null)
							dictBBoxesMapChords[pageNumber] = []
						if (cursor.element.type == Element.CHORD)
							dictBBoxesMapChords[pageNumber][eventId] = "C"
						else
							dictBBoxesMapChords[pageNumber][eventId] = "R"
						dictBBoxesMapChords[pageNumber][eventId] += ";;" + x + ";" + y + ";" + w + ";" + h + ";" + bbx + ";" + bby

						// --- mapping of single notes
						if (dictBBoxesMapNotes[pageNumber] == null)
							dictBBoxesMapNotes[pageNumber] = []
						if (cursor.element.type == Element.REST)
							dictBBoxesMapNotes[pageNumber][eventId] = "R;;" + x + ";" + y + ";" + w + ";" + h + ";" + bbx + ";" + bby
						else {
							dictBBoxesMapNotes[pageNumber][eventId] = "N"

							for (var i = 0; i < cursor.element.notes.length; i++) {
								var x = cursor.element.notes[i].pagePos.x.toPrecision(6)
								var y = cursor.element.notes[i].pagePos.y.toPrecision(6)
								var w = cursor.element.notes[i].bbox.width.toPrecision(6)
								var h = cursor.element.notes[i].bbox.height.toPrecision(6)
								var bbx = cursor.element.notes[i].bbox.x.toPrecision(6)
								var bby = cursor.element.notes[i].bbox.y.toPrecision(6)
								dictBBoxesMapNotes[pageNumber][eventId] += ";;" + x + ";" + y + ";" + w + ";" + h + ";" + bbx + ";" + bby
							}
						}

						// LOS

						// duration
						var augDots = 0
						var candidateNum = cursor.element.duration.numerator
						var candidateDen = cursor.element.duration.denominator
						if (candidateNum == 7) {
							candidateNum -= 1
							augDots++
							var newFraction = reduceFraction(candidateNum, candidateDen)
							candidateNum = newFraction[0]
							candidateDen = newFraction[1]
						}
						if (candidateNum == 3) {
							candidateNum -= 1
							augDots++
							var newFraction = reduceFraction(candidateNum, candidateDen)
							candidateNum = newFraction[0]
							candidateDen = newFraction[1]
						}
						var fractionDuration = reduceFraction(candidateNum, candidateDen)
						candidateNum = fractionDuration[0]
						candidateDen = fractionDuration[1]

						// tuplet
						var isTuplet = false
						if (cursor.element.duration.numerator != cursor.element.globalDuration.numerator || cursor.element.duration.denominator != cursor.element.globalDuration.denominator) {
							isTuplet = true
							var enterFract = reduceFraction(cursor.element.duration.numerator * (cursor.element.globalDuration.denominator / cursor.element.duration.denominator), cursor.element.duration.denominator)
							var inFract = reduceFraction(cursor.element.duration.numerator * cursor.element.globalDuration.numerator, cursor.element.globalDuration.denominator / (cursor.element.globalDuration.denominator / cursor.element.duration.denominator))
						}

						if (cursor.element.type == Element.CHORD) {
							var chord = cursor.element
							var chordS = "C" + ";;" + eventId + ";;" + candidateNum + ";" + candidateDen + ";" + augDots + ";"
							if (isTuplet)
								chordS += enterFract[0] + "," + enterFract[1] + "," + inFract[0] + "," + inFract[1]
							else
								chordS += ",,,"
							chordS += ";;"
							// notes
							for (var i = 0; i < chord.notes.length; i++) {
								if (curScore.parts[partIdx].hasPitchedStaff) {
									chordS += getStep(chord.notes[i]) + "," + getOctave(chord.notes[i]) + "," + getActualAccidental(chord.notes[i]) + ","
									if (chord.notes[i].accidental)
										chordS += getPrintedAccidentals(chord.notes[i])
									chordS += ","
								} else {
									chordS += "none,-1,none,,"
								}
								if (chord.notes[i].tieFor)
									chordS += "T"
								chordS += ";"
							}
							sequence.push(chordS)
							// Lyrics
							dictLyrics[partName + ";" + voiceId] += parseLyrics(chord, eventId)
						} else if (cursor.element.type == Element.REST) {
							var restS = "R" + ";;" + eventId + ";;" + candidateNum + ";" + candidateDen + ";" + augDots + ";"
							if (isTuplet)
								restS += enterFract[0] + "," + enterFract[1] + "," + inFract[0] + "," + inFract[1]
							else
								restS += ",,,"
							restS += ";;"
							sequence.push(restS)
						}
						dictParts[partName][measNum + 1][voiceId] = sequence
					}
				} while (cursor.next())
			}
		}
	}

	function reduceFraction(numerator, denominator) {
		var gcd = function gcd(a, b) {
			return b ? gcd(b, a % b) : a
		}
		gcd = gcd(numerator, denominator);
		return [numerator / gcd, denominator / gcd];
	}

	function indent(n) {
		var result = ""
		for (var i = 0; i < n; i++)
			result += "\t"
		return result
	}




	// ******************************************************************
	//
	// GUI
	//
	// ******************************************************************


	// File names -------------------------------------------------

	Label {
		id: labelSpacerFilePathName
		text: ""
		font.pixelSize: fontSize
		width: smallWidth
		height: bigHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}

	Label {
		id: labelFilePathName
		text: "File path and name"
		font.pixelSize: fontTitleSize
		anchors.left: labelSpacerFilePathName.right
		width: smallWidth
		height: bigHeight
		verticalAlignment: Text.AlignVCenter
	}

	// File name

	Label {
		id: labelFileName
		text: "File name  "
		font.pixelSize: fontSize
		anchors.top: labelSpacerFilePathName.bottom;
		width: smallWidth
		height: stdHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}

	TextField {
		id: textFieldFileName
		placeholderText: qsTr("file name")
		text: curScore.name + ".xml"
		anchors.top: labelSpacerFilePathName.bottom;
		anchors.left: labelFileName.right;
		width: mediumWidth
		height: stdHeight
	}

	Button {
		id: buttonFileName
		text: "↺ Reset"
		anchors.top: labelSpacerFilePathName.bottom;
		anchors.left: textFieldFileName.right;
		width: buttonWidth
		height: stdHeight

		MouseArea {
			anchors.fill: parent
			onClicked: textFieldFileName.text = curScore.name + ".xml"
		}
	}

	// Path

	Label {
		id: labelFilePath
		text: "File path  "
		font.pixelSize: fontSize
		anchors.top: labelFileName.bottom;
		width: smallWidth
		height: stdHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}

	TextField {
		id: textFieldFilePath
		placeholderText: qsTr("file path")
		anchors.top: labelFileName.bottom
		anchors.left: labelFilePath.right
                                             text: ""
		width: bigWidth
		height: stdHeight
		enabled: false
	}

	Button {
		id: buttonFilePath
		text: "📂 Choose"
		anchors.top: labelFileName.bottom;
		anchors.left: textFieldFilePath.right;
		width: buttonWidth
		height: stdHeight

		MouseArea {
			anchors.fill: parent
			onClicked: directorySelectDialog.open()
		}
	}

	// General ----------------------------------------------------

	Label {
		id: labelSpacerGeneral
		text: ""
		font.pixelSize: fontSize
		anchors.top: labelFilePath.bottom
		width: smallWidth
		height: bigHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}

	Label {
		id: labelGeneral
		text: "General layer"
		font.pixelSize: fontTitleSize
		anchors.top: labelFilePath.bottom
		anchors.left: labelSpacerGeneral.right
		width: smallWidth
		height: bigHeight
		verticalAlignment: Text.AlignVCenter
	}

	// Title

	Label {
		id: labelTitle
		text: "Title  "
		font.pixelSize: fontSize
		anchors.top: labelGeneral.bottom;
		width: smallWidth
		height: stdHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}

	TextField {
		id: textFieldTitle
		placeholderText: qsTr("title")
		anchors.top: labelGeneral.bottom;
		anchors.left: labelTitle.right;
		text: curScore.title
		width: bigWidth
		height: stdHeight
	}

	Button {
		id: buttonTitle
		text: "↺ Reset"
		anchors.top: labelGeneral.bottom;
		anchors.left: textFieldTitle.right;
		width: buttonWidth
		height: stdHeight

		MouseArea {
			anchors.fill: parent
			onClicked: textFieldTitle.text = curScore.name
		}
	}

	// Number

	Label {
		id: labelNumber
		text: "Number  "
		font.pixelSize: fontSize
		anchors.top: labelTitle.bottom;
		width: smallWidth
		height: stdHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}

	TextField {
		id: textFieldNumber
		placeholderText: qsTr("number")
		anchors.top: labelTitle.bottom;
		anchors.left: labelNumber.right;
		width: bigWidth
		height: stdHeight
	}

	Button {
		id: buttonNumber
		text: "↺ Reset"
		anchors.top: labelTitle.bottom;
		anchors.left: textFieldNumber.right;
		width: buttonWidth
		height: stdHeight

		MouseArea {
			anchors.fill: parent
			onClicked: textFieldNumber.text = ""
		}
	}

	// Work title

	Label {
		id: labelWorkTitle
		text: "Work title  "
		font.pixelSize: fontSize
		anchors.top: labelNumber.bottom;
		width: smallWidth
		height: stdHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}

	TextField {
		id: textFieldWorkTitle
		placeholderText: qsTr("work title")
		anchors.top: labelNumber.bottom;
		anchors.left: labelTitle.right;
		width: bigWidth
		height: stdHeight
	}

	Button {
		id: buttonWorkTitle
		text: "↺ Reset"
		anchors.top: labelNumber.bottom;
		anchors.left: textFieldWorkTitle.right;
		width: buttonWidth
		height: stdHeight

		MouseArea {
			anchors.fill: parent
			onClicked: textFieldWorkTitle.text = ""
		}
	}

	// Work number

	Label {
		id: labelWorkNumber
		text: "Work number  "
		font.pixelSize: fontSize
		anchors.top: labelWorkTitle.bottom;
		width: smallWidth
		height: stdHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}

	TextField {
		id: textFieldWorkNumber
		placeholderText: qsTr("work number")
		anchors.top: labelWorkTitle.bottom;
		anchors.left: labelWorkNumber.right;
		width: bigWidth
		height: stdHeight
	}

	Button {
		id: buttonWorkNumber
		text: "↺ Reset"
		anchors.top: labelWorkTitle.bottom;
		anchors.left: textFieldWorkNumber.right;
		width: buttonWidth
		height: stdHeight

		MouseArea {
			anchors.fill: parent
			onClicked: textFieldWorkNumber.text = ""
		}
	}

	// Composer

	Label {
		id: labelAuthorMusic
		text: "Author (music)  "
		font.pixelSize: fontSize
		anchors.top: labelWorkNumber.bottom;
		width: smallWidth
		height: stdHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}

	TextField {
		id: textFieldAuthorMusic
		anchors.top: labelWorkNumber.bottom;
		anchors.left: labelAuthorMusic.right;
		placeholderText: qsTr("composer")
		text: curScore.composer
		width: mediumWidth
		height: stdHeight
	}

	Button {
		id: buttonAuthorMusic
		text: "↺ Reset"
		anchors.top: labelWorkNumber.bottom;
		anchors.left: textFieldAuthorMusic.right;
		width: buttonWidth
		height: stdHeight

		MouseArea {
			anchors.fill: parent
			onClicked: textFieldAuthorMusic.text = curScore.composer
		}
	}

	// Poet

	Label {
		id: labelAuthorLyrics
		text: "Author (lyrics)  "
		font.pixelSize: fontSize
		anchors.top: labelAuthorMusic.bottom;
		width: smallWidth
		height: stdHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}

	TextField {
		id: textFieldAuthorLyrics
		anchors.top: labelAuthorMusic.bottom;
		anchors.left: labelAuthorLyrics.right;
		placeholderText: qsTr("lyricist")
		text: curScore.lyricist
		width: mediumWidth
		height: stdHeight
	}

	Button {
		id: buttonAuthorLyrics
		text: "↺ Reset"
		anchors.top: labelAuthorMusic.bottom;
		anchors.left: textFieldAuthorLyrics.right;
		width: buttonWidth
		height: stdHeight

		MouseArea {
			anchors.fill: parent
			onClicked: textFieldAuthorLyrics.text = curScore.poet
		}
	}

	// Notational ----------------------------------------------------

	Label {
		id: labelSpacerNotational
		text: ""
		font.pixelSize: fontSize
		anchors.top: labelAuthorLyrics.bottom;
		width: smallWidth
		height: bigHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}

	Label {
		id: labelNotational
		text: "Notational layer"
		font.pixelSize: fontTitleSize
		anchors.top: labelAuthorLyrics.bottom;
		anchors.left: labelSpacerGeneral.right
		width: smallWidth
		height: bigHeight
		verticalAlignment: Text.AlignVCenter
	}

	Label {
		id: labelEnableExport
		text: "Enable export  "
		font.pixelSize: fontSize
		anchors.top: labelSpacerNotational.bottom;
		width: smallWidth
		height: stdHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}

	CheckBox {
		id: checkEnableExport
		anchors.top: labelSpacerNotational.bottom;
		anchors.left: labelAuthorLyrics.right;
		checked: true

		MouseArea {
			anchors.fill: parent
			onClicked: {
				checkEnableExport.checked = !checkEnableExport.checked
				if (labelDPI.opacity == 1)
					labelDPI.opacity = 0.5
				else
					labelDPI.opacity = 1
				textFieldDPI.enabled = !textFieldDPI.enabled
				buttonDPI.enabled = !buttonDPI.enabled
				if (labelDistance.opacity == 1)
					labelDistance.opacity = 0.5
				else
					labelDistance.opacity = 1
				textFieldDistance.enabled = !textFieldDistance.enabled
				buttonDistance.enabled = !buttonDistance.enabled
				if (labelMap.opacity == 1)
					labelMap.opacity = 0.5
				else
					labelMap.opacity = 1
				radioButtonChords.enabled = !radioButtonChords.enabled
				radioButtonNotes.enabled = !radioButtonNotes.enabled
			}
		}
	}

	Label {
		id: labelEnableExportExplain
		text: "Check to automatically export graphic mappings from MuseScore. Graphical files must be produced in PNG format from File > Export."
		font.pixelSize: fontSize
		anchors.top: labelSpacerNotational.bottom;
		anchors.left: checkEnableExport.right;
		width: bigWidth
		height: bigHeight
		horizontalAlignment: Text.AlignLeft
		wrapMode: Text.WordWrap
	}


	Label {
		id: labelMap
		text: "Mappings around  "
		font.pixelSize: fontSize
		anchors.top: labelEnableExportExplain.bottom;
		width: smallWidth
		height: stdHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}


	RowLayout {

		anchors.top: labelEnableExportExplain.bottom;
		anchors.left: labelMap.right;

		ExclusiveGroup {
			id: groupBoxMappingAround
		}
		RadioButton {
			id: radioButtonChords
			text: "chords"
			checked: true
			exclusiveGroup: groupBoxMappingAround
		}
		RadioButton {
			id: radioButtonNotes
			text: "notes"
			exclusiveGroup: groupBoxMappingAround
		}
	}

	Label {
		id: labelGraphicalGroupDesc
		text: "Description  "
		font.pixelSize: fontSize
		anchors.top: labelMap.bottom;
		width: smallWidth
		height: stdHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}

	TextField {
		id: textFieldGraphicalGroupDesc
		anchors.top: labelMap.bottom;
		anchors.left: labelGraphicalGroupDesc.right;
		placeholderText: qsTr("Score description")
		text: qsTr("MuseScore transcription")
		width: bigWidth
		height: stdHeight
	}

	Button {
		id: buttonGraphicalGroupDesc
		text: "↺ Reset"
		anchors.top: labelMap.bottom;
		anchors.left: textFieldGraphicalGroupDesc.right;
		width: buttonWidth
		height: stdHeight

		MouseArea {
			anchors.fill: parent
			onClicked: textFieldGraphicalGroupDesc.text = qsTr("MuseScore transcription")
		}
	}

	Label {
		id: labelDPI
		text: "DPI  "
		font.pixelSize: fontSize
		anchors.top: labelGraphicalGroupDesc.bottom;
		width: smallWidth
		height: stdHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}

	TextField {
		id: textFieldDPI
		anchors.top: labelGraphicalGroupDesc.bottom;
		anchors.left: labelDPI.right;
		placeholderText: qsTr("DPI value")
		text: qsTr("300")
		width: mediumWidth
		height: stdHeight
	}

	Button {
		id: buttonDPI
		text: "↺ Reset"
		anchors.top: labelGraphicalGroupDesc.bottom;
		anchors.left: textFieldDPI.right;
		width: buttonWidth
		height: stdHeight

		MouseArea {
			anchors.fill: parent
			onClicked: textFieldDPI.text = qsTr("300")
		}
	}

	Label {
		id: labelDistance
		text: "Line distance (mm)  "
		font.pixelSize: fontSize
		anchors.top: labelDPI.bottom;
		width: smallWidth
		height: stdHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}

	TextField {
		id: textFieldDistance
		anchors.top: labelDPI.bottom;
		anchors.left: labelDistance.right;
		placeholderText: qsTr("distance between staff lines in mm")
		text: qsTr("1.764")
		width: mediumWidth
		height: stdHeight
	}

	Button {
		id: buttonDistance
		text: "↺ Reset"
		anchors.top: labelDPI.bottom;
		anchors.left: textFieldDistance.right;
		width: buttonWidth
		height: stdHeight

		MouseArea {
			anchors.fill: parent
			onClicked: textFieldDistance.text = qsTr("1.764")
		}
	}

	// Confirm ----------------------------------------------------

	Label {
		id: labelSpacerConfirm1
		text: " "
		font.pixelSize: fontSize
		anchors.top: labelDPI.bottom;
		width: smallWidth
		height: bigHeight
		horizontalAlignment: Text.AlignRight
		verticalAlignment: Text.AlignVCenter
	}

	Button {
		id: buttonConvert
		text: "✓ Convert"
		anchors.top: labelSpacerConfirm1.bottom;
		anchors.left: labelSpacerConfirm1.right;
		width: buttonWidth
		height: stdHeight

		MouseArea {
			anchors.fill: parent
			onClicked: createXML()
		}
	}

	Label {
		id: labelInterButtons
		text: "  "
		font.pixelSize: fontSize
		anchors.top: labelSpacerConfirm1.bottom;
		anchors.left: buttonConvert.right;
		height: stdHeight
	}

	Button {
		id: buttonClose
		text: "✕ Close"
		anchors.top: labelSpacerConfirm1.bottom;
		anchors.left: labelInterButtons.right;
		width: buttonWidth
		height: stdHeight

		MouseArea {
			anchors.fill: parent
			onClicked: Qt.quit()
		}
	}
}
