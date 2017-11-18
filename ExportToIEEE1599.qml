import QtQuick 2.2
import QtQuick.Controls 1.1
import QtQuick.Layouts 1.1
import QtQuick.Dialogs 1.2
import Qt.labs.settings 1.0
// FileDialog
import Qt.labs.folderlistmodel 2.1
import QtQml 2.2
import MuseScore 1.0
import FileIO 1.0

MuseScore {
      menuPath: "Plugins." + "Export to IEEE 1599"
      version: "1.1"
      description: "Export to IEEE 1599 format..."
      pluginType: "dialog"

      property string crlf : "\r\n"
      property string filename : ""
      property int vtuPerQuarter : division

      onRun: {     
            // check MuseScore version
            if (!(mscoreMajorVersion > 1 && (mscoreMinorVersion > 0 || mscoreUpdateVersion > 0)))
                  errorDialog.openErrorDialog(qsTr("Minimum MuseScore Version %1 required for export").arg("2.0.1"))
            if (!(curScore)) {
                  errorDialog.openErrorDialog(qsTranslate("QMessageBox","No score available.\nThis plugin requires an open score to run.\n"))
                  Qt.quit()
            } else {
            // directorySelectDialog.folder = ((Qt.platform.os == "windows")? "file:///" : "file://") + "my_dir";
                  directorySelectDialog.open() // Go to Step 1
            }
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
                  Qt.quit()
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
            text: "Score has been successfully converted to IEEE 1599 format." + crlf + "Resulting file: " + filename + crlf + crlf
            onAccepted: {
                  Qt.quit()
		}
            function openEndDialog(message) {
                  text = message
                  open()
            }
      }
      
      // Step 1: choose directory
      FileDialog {
            id: directorySelectDialog
            title: qsTr("Please choose a directory")
            selectFolder: true
            visible: false
            onAccepted: {
                  var exportDirectory = this.folder.toString().replace("file://", "").replace(/^\/(.:\/)(.*)$/, "$1$2")
                  console.log ("Selected directory: " + exportDirectory)
                  var scoreFilename = filenameFromScore()
                  if (scoreFilename == "")
                        scoreFilename = "export"
                  filename = exportDirectory + "/" + scoreFilename + ".xml"
                  console.log("Complete filename: " + filename)
                  createXML(filename)
            }
            onRejected: {
                  console.log("Directory not selected")
                  Qt.quit()
            }
            Component.onCompleted: visible = false
      }

      // Step 2: create XML
      function createXML(filename) {
            var crlf = "\r\n"
            var xml = "<?xml version='1.0' encoding='UTF-8'?>" + crlf
            xml += createDocType()
            xml += "<ieee1599 version='1.0' creator='MuseScore Export Plugin " + version + "'>" + crlf
            xml += createGeneral()
            xml += createLogic()
            xml += "</ieee1599>"
            // console.log("Resulting XML:" + crlf + xml)
            xmlWriter.source = filename
	    console.log ("Writing XML...")
            xmlWriter.write(xml)
            console.log ("Conversion performed")
            endDialog.open()
      }

      // Step 2.1: DOCTYPE
      function createDocType() {
            var crlf = "\r\n"
            var result = "<!DOCTYPE ieee1599 SYSTEM 'http://www.lim.di.unimi.it/IEEE/ieee1599.dtd'>" + crlf
            return result
      }

      // Step 2.2: create General
      function createGeneral() {
            console.log ("Compiling the General layer...")
            var result = indent(1) + "<general>" + crlf
            result += indent(2)+ "<description>" + crlf
            result += indent(3)+ "<main_title>"
            result += unescape(encodeURIComponent(curScore.title))
            console.log("General > title: " + unescape(encodeURIComponent(curScore.title)))
            result += "</main_title>" + crlf
            result += indent(3)+ "<author type='composer'>"
            result += unescape(encodeURIComponent(curScore.composer))
            console.log("General > author[composer]: " + unescape(encodeURIComponent(curScore.composer)))
            result += "</author>" + crlf
            if (curScore.poet) {
                  result += indent(3)+ "<author type='poet'>"
                  result += unescape(encodeURIComponent(curScore.poet))
                  console.log("General > author[poet]: " + unescape(encodeURIComponent(curScore.poet)))
                  result += "</author>" + crlf
            }
            result += indent(2)+ "</description>" + crlf
            result += indent(1)+ "</general>" + crlf
            return result
      }

      // Step 2.3: create Logic
      function createLogic() {
            console.log ("Compiling the Logic layer...")
            var result = indent(1)+ "<logic>" + crlf
            var createSpineResult = createSpine()
            var createSpineResults = createSpineResult.split("||")
            result += createSpineResults[0]
            result += createLOS(createSpineResults[1], createSpineResults[2])
            result += indent(1)+ "</logic>" + crlf
            return result
      }

      // Step 2.3.1: create Spine
      function createSpine() {
            console.log("Creating the spine...")
            var result = indent(2)+ "<spine>" + crlf
            var keySignatures = "||"
            var timeSignatures = "||"

            // create dictionary using tick number as a key
            var dict = [];
            var cursor = curScore.newCursor()
            var oldPartName
            var voiceDelta = 0
            var voiceIncrementalNumber = 1
            for (var j = 0; j < curScore.nstaves; j++) {
                  cursor.staffIdx = j
                  var firstClefInserted = false
                  var currentPartName = getPartNameFromStaffIndex(cursor.staffIdx)
                  if (currentPartName != oldPartName) {
                        voiceDelta = 0
                        voiceIncrementalNumber = 1
                  }
                  else
                        voiceDelta = voiceDelta + 4
                  
                  oldPartName = currentPartName   
                  for (var i = 0; i < 4; i++) {
                        cursor.voice = i
                        cursor.rewind(0)
                        var eventCounter = 1
                        var measureCounter = 0
                        var old_meas = 0
                        var old_key = null
                        var old_time = null
                        var atLeastOneEvent = false;
                        do {
                              if (cursor.measure != old_meas) {
                                    measureCounter++
                                    eventCounter = 1
                              }
                              old_meas = cursor.measure                        
      
                              // Clef
                              if (!firstClefInserted) {
                                    var id = currentPartName + "_staff" + ((voiceDelta / 4) + 1) + "_clef"
                                    // tick expressed on 16 digits -> key; event id -> value
                                    if (dict[zeroPad(cursor.tick, 16)])
                                          dict[zeroPad(cursor.tick, 16)] += ";" + id
                                    else
                                          dict[zeroPad(cursor.tick, 16)] = id
                                    keySignatures += currentPartName + "_staff" + ((voiceDelta / 4) + 1) + ",," + id + ",," + cursor.keySignature + ";;"
                                    firstClefInserted = true
                              }
                              // Key signature
                              if (cursor.keySignature != old_key && (i % 4 == 0)) {
                                    old_key = cursor.keySignature
                                    var id = currentPartName + "_staff" + ((voiceDelta / 4) + 1) + "_meas" + measureCounter + "_keysig"
                                    // tick expressed on 16 digits -> key; event id -> value
                                    if (dict[zeroPad(cursor.tick, 16)])
                                          dict[zeroPad(cursor.tick, 16)] += ";" + id
                                    else
                                          dict[zeroPad(cursor.tick, 16)] = id
                                    keySignatures += currentPartName + "_staff" + ((voiceDelta / 4) + 1) + ",," + id + ",," + cursor.keySignature + ";;"
                              }
                              // Time signature
                              if (cursor.timeSignature != old_time && (i % 4 == 0)) {
                                    old_time = cursor.timeSignature
                                    var id = currentPartName + "_staff" + ((voiceDelta / 4) + 1) + "_meas" + measureCounter + "_timesig"
                                    // tick expressed on 16 digits -> key; event id -> value
                                    if (dict[zeroPad(cursor.tick, 16)])
                                          dict[zeroPad(cursor.tick, 16)] += ";" + id
                                    else
                                          dict[zeroPad(cursor.tick, 16)] = id
                                    // console.log(vtuPerQuarter)
                                    var totalVtus = vtuPerQuarter * cursor.timeSignature.numerator * (4 / cursor.timeSignature.denominator)
                                    timeSignatures += currentPartName + "_staff" + ((voiceDelta / 4) + 1) + ",," + id + ",," + cursor.timeSignature.numerator + ",," + cursor.timeSignature.denominator  + ",," + totalVtus + ";;"
                              }

                              if (cursor.element != null && (cursor.element.type == Element.CHORD || cursor.element.type == Element.REST)) {  
                                    // event id
                                    var id = getEventId(currentPartName, measureCounter, voiceIncrementalNumber, eventCounter)
                                    // tick expressed on 16 digits -> key; event id -> value
                                    if (dict[zeroPad(cursor.tick, 16)])
                                          dict[zeroPad(cursor.tick, 16)] += ";" + id
                                    else
                                          dict[zeroPad(cursor.tick, 16)] = id
                                    eventCounter++
                                    atLeastOneEvent = true
                              }
                        }
                        while (cursor.next()) 
                        if (atLeastOneEvent)
                              voiceIncrementalNumber++
                  }
            }

            // sort to obtain spine
            var sorted = [];
            for(var key in dict) {
                  sorted[sorted.length] = key;
            }
            sorted.sort();

            for(var i = 0; i < sorted.length; i++) {
                  var delta = i > 0 ? parseInt(sorted[i],10) - parseInt(sorted[i-1],10) : 0
                  var candidateIds = dict[sorted[i]].split(";")
                  for (var c = 0; c < candidateIds.length; c++) {
                        result += indent(3)+ "<event id='" + candidateIds[c] + "' "
                        result += "timing='" + delta + "' "
                        result += "hpos='" + delta + "' "
                        result += "/>" + crlf
                        delta = 0
                  }
            }

            result += indent(2)+ "</spine>" + crlf
            return result + keySignatures + timeSignatures
      }

      // Step 2.3.2: create LOS
      function createLOS(keySignatures, timeSignatures) {
            console.log("Creating logically organized symbols...")

            var keySignatures = keySignatures.split(";;")
            var timeSignatures = timeSignatures.split(";;")
            var result = indent(2)+ "<los>" + crlf
            var lyrics = ""
            
            // Staff list
            result += indent(3)+ "<staff_list>" + crlf
            var oldPartName = ""
            var staff_counter = 1
            for (var staffIndex = 0; staffIndex < curScore.nstaves; staffIndex++) {
                  if (getPartNameFromStaffIndex(staffIndex) != oldPartName) {
                        oldPartName = getPartNameFromStaffIndex(staffIndex)
                        staff_counter = 1
                  }
                  var staffName = getPartNameFromStaffIndex(staffIndex) + "_staff" + staff_counter
                  result += indent(4)+ "<staff id='" + staffName + "' line_number='"
                  
                  /*
                  if (curScore.parts[j].hasDrumStaff)
                        result += "1"
                  else*/
                        result += "5"

                  result += "'>" + crlf
                  var aggregatedClef = getClef(staffIndex)
                  var disaggregatedClef = aggregatedClef.split("_")
                  result += indent(5)+ "<clef event_ref='" + staffName + "_clef' shape='" + disaggregatedClef[0] + "' staff_step='" + disaggregatedClef[1] + "' />" + crlf
                        
                  // Key signatures
                        for (var ks = 0; ks < keySignatures.length; ks++) {
                              var keySignature = keySignatures[ks].split(",,")
                              if (keySignature[0] == staffName) {
                                    result += indent(5)+ "<key_signature event_ref='" + keySignature[1] + "'>" + crlf
                                    var accidentals = parseInt(keySignature[2])
                                    if (accidentals >= 0)
                                          result += indent(6)+ "<sharp_num number='" + accidentals + "'/>" + crlf
                                    else
                                          result += indent(6)+ "<flat_num number='" + (accidentals * -1) + "'/>" + crlf
                                    result += indent(5)+ "</key_signature>" + crlf
                              }    
                        }
                        
                  // Time signatures
                        for (var ts = 0; ts < timeSignatures.length; ts++) {
                              var timeSignature = timeSignatures[ts].split(",,")
                              if (timeSignature[0] == staffName) {
                                    result += indent(5)+ "<time_signature event_ref='" + timeSignature[1] + "'>" + crlf
                                    result += indent(6)+ "<time_indication num='" + parseInt(timeSignature[2]) + "' den='" + parseInt(timeSignature[3]) + "' vtu_amount='" + timeSignature[4] + "' />" + crlf
                                    result += indent(5)+ "</time_signature>" + crlf
                              }    
                        }
      
                  result += indent(4)+ "</staff>" + crlf
                  staff_counter++
            }
            result += indent(3)+ "</staff_list>" + crlf

            // Parts
            for (var partIdx = 0; partIdx < curScore.parts.length; partIdx++) {
                  var currentPartName = getPartNameFromPartIndex(partIdx)
                  var trackIdxsToParse = getRealTrackIdxsOfPart(partIdx)
                  var voiceNamesToParse = []
                  result += indent(3)+ "<part id='" + currentPartName + "'" + getPartTransposition(partIdx) + ">" + crlf
                  // Voice list (for parts)
                  result += indent(4)+ "<voice_list>" + crlf
                  var voiceCounter = trackIdxsToParse.length
                  for (var voiceIdx = 1; voiceIdx <= voiceCounter; voiceIdx++) {
                        var id = currentPartName + "_voice" + voiceIdx
                        var staffRef = getStaffNameFromPartAndVoice(partIdx, voiceIdx)
                        result += indent(5)+ "<voice_item id='" + id + "' staff_ref='" + currentPartName + "_staff" + staffRef + "' />" + crlf   
                        voiceNamesToParse[voiceIdx-1] = id
                  }
                  result += indent(4)+ "</voice_list>" + crlf
                  
                  // Measures
                  var measureToParse = 0
                  var cursor = curScore.newCursor()
                  var stopWhile = false
                  // Cycling on measures...
                  var oldPartForLyrics = ""
                  var oldVoiceForLyrics = ""
                  while (true) {
                        measureToParse++
                        cursor.rewind(0)
                        for (var advanceMeas = 1; advanceMeas < measureToParse; advanceMeas++) {
                              cursor.nextMeasure()
                              if (cursor.measure == null) {
                                    //console.log("Stopping measure advancement cycle...")
                                    stopWhile = true
                                    break
                              }
                        }
                        if (stopWhile == true) {
                              //console.log("Stopping measure cycle...")
                              break
                        }
                        result += indent(4)+ "<measure number='" + measureToParse + "'>" + crlf
                        
                        // Voicing per measure
                        for (var v = 0; v < trackIdxsToParse.length; v++) {
                              var innerCursor = curScore.newCursor()
                              var atLeastOneEvent = false
                              var currentLyrics = ""
                              innerCursor.track = trackIdxsToParse[v]
                              innerCursor.rewind(0)
                              // move cursor to current measure
                              do {
                                    // console.log(innerCursor.tick + " " + cursor.tick)
                                    if (innerCursor.tick >= cursor.tick)
                              		break
                              }
                              while (innerCursor.nextMeasure())
                              var eventNum = 0
                         
                              // Chords and rests (and lyrics)
                              var currentMeasure = innerCursor.measure
                              do
                                    if (innerCursor.element != null) {
                                          eventNum++
                                          if (!atLeastOneEvent)
                                                result += indent(5)+ "<voice voice_item_ref='" + voiceNamesToParse[v] + "'>" + crlf
                                          atLeastOneEvent = true
                                          var eventId = getEventId(currentPartName, measureToParse, (v + 1), eventNum)
                                          // console.log (eventId)
                                          if (innerCursor.element.type == Element.CHORD) {
                                                result += parseChord(innerCursor.element, eventId, curScore.parts[partIdx].hasPitchedStaff)
                                                // Lyrics
                                                currentLyrics += parseLyrics(innerCursor.element, eventId)
                                          }
                                          else if (innerCursor.element.type == Element.REST)
                                                result += parseRest(innerCursor.element, eventId)
                                    }
                              while (innerCursor.next() && innerCursor.measure == currentMeasure)
                              if (atLeastOneEvent)
                                    result += indent(5)+ "</voice>" + crlf
                              
                              // Lyrics 
                              if (currentLyrics != "") {
                              	if (currentPartName != oldPartForLyrics || voiceNamesToParse[v] != oldVoiceForLyrics) {
                              		if (oldPartForLyrics != "")
                              			lyrics += indent(3) + "</lyrics>"
                              		lyrics += indent(3) + "<lyrics part_ref='" + currentPartName + "' voice_ref='" + voiceNamesToParse[v] + "'>" + crlf
                              	}
                              	lyrics += currentLyrics
                              	oldPartForLyrics = currentPartName
                        	oldVoiceForLyrics = voiceNamesToParse[v]
                              }
                        }
                        result += indent(4)+ "</measure>" + crlf
                  }
                  
                  result += indent(3)+ "</part>" + crlf
            }

	    if (lyrics != "")
	    	result += lyrics + indent(3) + "</lyrics>" + crlf
            result += indent(2)+ "</los>" + crlf
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

      function getPartNameFromStaffIndex(idx) {
            var candidatePartName = ""
            var candidatePartIndex = -1
            for (var j = 0; j < curScore.parts.length; j++) {
                  // console.log("j=" + j + "; Part: " + curScore.parts[j].longName + "; Start: " + curScore.parts[j].startTrack + "; End: " + curScore.parts[j].endTrack)
                  if (idx >= (curScore.parts[j].startTrack / 4) && idx <= ((curScore.parts[j].endTrack - 1) / 4)) {
                        candidatePartName = curScore.parts[j].longName
                        candidatePartIndex = j
                        break
                  }
            }
            candidatePartName = candidatePartName.toLowerCase().replace(/ /g, "_").replace(/[^a-zA-Z0-9_]+/g, "")
            if (candidatePartName == null || candidatePartName == "")
                  candidatePartName = "part" + (j + 1)
            return candidatePartName
      }

      function getPartNameFromPartIndex(idx) {
            var candidatePartName = curScore.parts[idx].longName.toLowerCase().replace(/ /g, "_").replace(/[^a-zA-Z0-9_]+/g, "")
            if (candidatePartName == null || candidatePartName == "")
                  candidatePartName = "part" + (j + 1)
            return candidatePartName
      }

      function countVoicesOfPart(partIdx) {
            var counter = 0
            var tempCursor = curScore.newCursor()
            var startTrack = curScore.parts[partIdx].startTrack
            // console.log("Start track: " + startTrack)
            var endTrack = curScore.parts[partIdx].endTrack
            // console.log("End track: " + endTrack)
            for (var j = startTrack; j < endTrack; j++) { // Note that endTrack is excluded!
                  tempCursor.track = j
                  tempCursor.rewind(0)
                  while (tempCursor.next())
                        if (tempCursor.element != null && (tempCursor.element.type == Element.CHORD || tempCursor.element.type == Element.REST)) {
                              counter++
                              break
                        }
            }
            // console.log(counter)
            return counter
      }

      function getRealTrackIdxsOfPart(partIdx) {
            var trackIdxs = []
            var tempCursor = curScore.newCursor()
            var startTrack = curScore.parts[partIdx].startTrack
            // console.log("Start track: " + startTrack)
            var endTrack = curScore.parts[partIdx].endTrack
            // console.log("End track: " + endTrack)
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

      function getStaffNameFromPartAndVoice(partIdx, voiceIdx) {
            var counter = 0
            var tempCursor = curScore.newCursor()
            var startTrack = curScore.parts[partIdx].startTrack
            // console.log("Start track: " + startTrack)
            var endTrack = curScore.parts[partIdx].endTrack
            // console.log("End track: " + endTrack)
            for (var j = startTrack; j < endTrack; j++) { // Note that endTrack is excluded!
                  tempCursor.track = j
                  tempCursor.rewind(0)
                  do
                        if (tempCursor.element != null && (tempCursor.element.type == Element.CHORD || tempCursor.element.type == Element.REST)) {
                              counter++
                              break
                        }
                  while (tempCursor.next())
					if (counter == voiceIdx) {
                        var result = Math.floor((j - startTrack) / 4) + 1
                        // console.log ("Voice " + voiceIdx + " >>> Staff " + result)
                        return result
					}
            }
            return 0
      }

      function parseChord(chord, eventId, isPitched) {
            var result = indent(6) + "<chord event_ref='" + eventId + "'>" + crlf
            // Augmentation dots
            var augDots = 0
            var candidateNum = chord.duration.numerator
            var candidateDen = chord.duration.denominator
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
            result += indent(7) + "<duration num='" + candidateNum + "' den='" + candidateDen + "'"
            if (chord.duration.numerator != chord.globalDuration.numerator || chord.duration.denominator != chord.globalDuration.denominator) {
                  result += ">" + crlf
                  var enterFract = reduceFraction(chord.duration.numerator * (chord.globalDuration.denominator / chord.duration.denominator), chord.duration.denominator)
                  result += indent(8) + "<tuplet_ratio enter_num='" + enterFract[0] + "' enter_den='" + enterFract[1] + "'"
                  var inFract = reduceFraction(chord.duration.numerator * chord.globalDuration.numerator, chord.globalDuration.denominator / (chord.globalDuration.denominator / chord.duration.denominator))
                  result += " in_num='" + inFract[0] + "' in_den='" + inFract[1] + "' />" + crlf
                  result += indent(7) + "</duration>" + crlf
            }
            else
                  result += " />" + crlf
            if (augDots > 0)
                  result += indent(7) + "<augmentation_dots number='" + augDots + "' />" + crlf
            for (var i = 0; i < chord.notes.length; i++) {
                  result += indent(7) + "<notehead>" + crlf
                  result += indent(8) + "<pitch step='"
                  if (isPitched)
                        result += getStep(chord.notes[i]) + "' octave='" + getOctave(chord.notes[i]) + "' actual_accidental='" + getActualAccidental(chord.notes[i]) + "' />" + crlf
                  else
                        result += "none' octave='-1' actual_accidental='none' />" + crlf
                  if (chord.notes[i].accidental)
                        result += getPrintedAccidentals(chord.notes[i])
                  if (chord.notes[i].tieFor)
                        result += indent(8) + "<tie />" + crlf
                  result += indent(7) + "</notehead>" + crlf
            }
            result += indent(6) + "</chord>" + crlf
            return result
      }

      function parseRest(rest, eventId) {
            var result = indent(6) + "<rest event_ref='" + eventId + "'>" + crlf
            // Augmentation dots
            var augDots = 0
            var candidateNum = rest.duration.numerator
            var candidateDen = rest.duration.denominator
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
            result += indent(7) + "<duration num='" + candidateNum + "' den='" + candidateDen + "'"
            // Tuplet
            if (rest.duration.numerator != rest.globalDuration.numerator || rest.duration.denominator != rest.globalDuration.denominator) {
                  result += ">" + crlf
                  var enterFract = reduceFraction(rest.duration.numerator * (rest.globalDuration.denominator / rest.duration.denominator), rest.duration.denominator)
                  result += indent(8) + "<tuplet_ratio enter_num='" + enterFract[0] + "' enter_den='" + enterFract[1] + "'"
                  var inFract = reduceFraction(rest.duration.numerator * rest.globalDuration.numerator, rest.globalDuration.denominator / (rest.globalDuration.denominator / rest.duration.denominator))
                  result += " in_num='" + inFract[0] + "' in_den='" + inFract[1] + "' />" + crlf
                  result += indent(7) + "</duration>" + crlf
            }
            else
                  result += " />" + crlf
            if (augDots > 0)
                  result += indent(7) + "<augmentation_dots number='" + augDots + "' />" + crlf
            result += indent(6) + "</rest>" + crlf
            return result
      }

      function getStep(note) {
            var step="none"
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
            var octave = note.ppitch / 12
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

      function getPrintedAccidentals(note) {
            var accidental = indent(8) + "<printed_accidentals"
            if (note.accidental.hasBracket)
                 accidental += " shape='bracketed'"
            else if (note.accidental.small)
                 accidental += " shape='small'"
            accidental += ">" + crlf
            accidental += indent(9)
            switch (note.accidental.accType) {
                  case Accidental.SHARP: 
                        accidental += "<sharp />" + crlf
                        break
                  case Accidental.FLAT: 
                        accidental += "<flat />" + crlf
                        break
                  case Accidental.SHARP2: 
                        accidental += "<double_sharp />" + crlf
                        break
                  case Accidental.FLAT2: 
                        accidental += "<double_flat />" + crlf
                        break
                  case Accidental.NATURAL: 
                        accidental += "<natural />" + crlf
                        break
            }
            accidental += indent(8) + "</printed_accidentals>" + crlf
            return accidental
      }
      
      function parseLyrics(chord, eventId) {
      	    var result = ""
     	    for (var i = 0; i < chord.lyrics.length; i++) {
				result += indent(4) + "<syllable start_event_ref='" + eventId + "'"
     		  
				if (chord.lyrics[i].syllabic === Lyrics.SINGLE || chord.lyrics[i].syllabic === Lyrics.END) {
					result += " hyphen='no'"
				}	 
				else {
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
                        	case 0: return "F_4"
                        	case 2: return "C_6"
                        	case 4: return "C_4"
                        	case 5: return "F_6"
                        	case 6: return "C_2"
                        	case 8: return "C_0"
                        	case 10:                       	
                        	default: return "G_2"
                        }
                  }
            }
            while (tempCursor.next())
            return "G_2"
      }

      function getEventId(partName, measNum, voiceNum, eventNum) {
            var candidateId = partName + "_meas" + measNum + "_voice" + voiceNum + "_ev" + eventNum
            return candidateId
      }

      function reduceFraction(numerator, denominator) {
            var gcd = function gcd(a, b) {
                  return b ? gcd(b, a % b) : a
            }
            gcd = gcd(numerator,denominator);
            return [numerator/gcd, denominator/gcd];
      }

      function indent(n) {
            var result = ""
            for (var i = 0; i < n; i++) 
                  result += "\t"
            return result
      }
}