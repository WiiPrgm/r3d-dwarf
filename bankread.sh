#check if magic is present at $bank
#if yes, check for magic in the next bank
#if no magic found, put entire 16k (check on this) header area for next bank in a variable
#check if variable is empty
#if variable is empty, it's likely the start of a new bank, so current bank is a single layer




#
offset=1610617344
bank=1
nhcd=1610613248
type=""
currentbankid=""
currentbankname=""
gamesize=""
gcmagic=""
wiimagic=""

listbanks() {

while (( bank <= 8 )); do

  currentbankid=$(dd if="$1" bs=1 skip=$offset count=6 status=none | strings)
  currentbankname=$(dd if="$1" bs=1 skip=$(( offset+6 )) count=64 status=none | strings | sed 's/^=//')
  wiimagic=$(xxd -s $(( offset+24 )) -l 4 -p "$1")
#  secondpartdatastart=$(( $(printf '%d\n' 0x$(xxd -s $(( offset+secondpartoffset+696 )) -l 4 -p $1)) *4 ))
#  second_wiimagic=$(xxd -s $(( secondpartdatastart + 28 )) -l 4 -p $1)
  gcmagic=$(xxd -s $(( offset+28 )) -l 4 -p "$1")
  gamesize=""

  firstpartoffset=$(( $(printf '%d\n' 0x$(xxd -s $(( offset+262176 )) -l 4 -p "$1")) *4 ))
  secondpartoffset=$(( $(printf '%d\n' 0x$(xxd -s $(( offset+262184 )) -l 4 -p "$1")) *4 ))
secondpartdatastart=$(( $(printf '%d\n' 0x$(xxd -s $(( offset+secondpartoffset+696 )) -l 4 -p "$1")) *4 ))
  unenc_bankstart=$(( offset+secondpartoffset+secondpartdatastart ))
  second_wiimagic=$(xxd -s $(( unenc_bankstart + 24 )) -l 4 -p "$1")
  enc_check=""
#part_size=$(( $(printf '%d\n' 0x$(xxd -s $(( secondpartoffset+700 )) -l 4 -p $1)) *4 ))
#Read game type from NHCD header. This will be blank if entry is deleted
	type=$(dd if=$1 bs=1 skip=$nhcd count=4 status=none | tr -d '\0\n')
#Determine game size based on NHCD header entry
#echo "check for wii magic"
#echo $offset
#echo $secondpartoffset
#echo $secondpartdatastart "2nd part data start"
#echo $(( offset+secondpartoffset+secondpartdatastart ))
#echo $second_wiimagic
#echo "stop magic"

	case "$type" in
		NN1L) gamesize="Single Layer" ;;
		GC1L) gamesize="Gamecube Game" ;;
		NN2L) gamesize="Dual Layer"
			offset=$((offset+4707319808))
			((bank++))
			nhcd=$((nhcd+512))
    			;;
		""|*) gamesize="Deleted Bank"
			type="Deleted"
    			;;
	esac

#displays stats if vars aren't empty.
#this was moved to the end

#	echo "Bank "$bank":"
#	[[ -n "$currentbankid" ]] && echo "$currentbankid"
#	[[ -n "$currentbankname" ]] && echo "$currentbankname"
#	#echo "$gamesize"; gamesize=""


#check game type against magic word in disc image
	if [[ "$wiimagic" == "5d1c9ea3" && "$gcmagic" == "00000000" ]]; then
		if [[ $type == NN* ]]; then
			gametype="Wii Game"
		#echo "$offset"
		#echo "$secondpartoffset"
		#echo $type
		elif [[ "$type"="Deleted" ]]; then
			gametype="Deleted Wii Game with header. (Easy to recover.)"
		elif [[ $type == GC* ]]; then
			gametype="Error. NHCD Header says Gamecube, but disc image doesn't match."
		else
			gametype="ERROR. Debug 1. How did you get here?"
		fi
	elif [[ "$gcmagic" == "c2339f3d" && "$wiimagic" == "00000000" ]]; then
		if [[ $type == GC* ]]; then
			gametype="Gamecube Game"
			#echo $type
		elif [[ "$type"="Deleted" ]]; then
			gametype="Deleted Gamecube Game with header. (Easy to recover.)"
		elif [[ $type == NN* ]]; then
			gametype="Error. NHCD header says Wii, but disc image doesn't match."
		else
			gametype="ERROR. Debug 2. How did you get here?"
		fi
	elif [[ "$gcmagic" == "00000000" && "$wiimagic" == "00000000" && "$type" == "Deleted" ]]; then
		gametype="ERROR. NHCD entry is blank and disc header is missing."
			if [[ "$second_wiimagic" == "5d1c9ea3" ]]; then
				enc_check="Disc is unencrypted. Disc header can be easily restored."
				currentbankid=$(dd if="$1" bs=1 skip="$unenc_bankstart" count=6 status=none | strings)
				currentbankname=$(dd if="$1" bs=1 skip=$(( unenc_bankstart+6 )) count=64 status=none | strings | sed 's/^=//')
			else
				enc_check="Disc type unknown. Unable to restore at this time."
			fi

#add logic if there are no magic words and no header entry. try to check for presence of a disc
	else
		gametype="Garbage Data Detected. This might be the second partiton of a deleted dual layer game."

fi

        echo "Bank "$bank":"
	[[ -n "$currentbankid" ]] && echo "$currentbankid"
	[[ -n "$currentbankname" ]] && echo "$currentbankname"
	[[ -n "$gamesize" && "$gamesize" != "Gamecube Game" ]] && echo "$gamesize"
	echo $gametype
	[[ -n "$enc_check" ]] && echo "$enc_check"
#	echo $second_wiimagic
#	echo $offset
#	echo $firstpartoffset
#	echo $secondpartoffset
#	echo "Data size start"
#	echo "$unenc_bankstart"
#	echo $(( offset + secondpartoffset + 700 ))
#	xxd -s $(( offset + secondpartoffset + 700 )) -l 4 "$1"
#	xxd -s $(( offset + secondpartoffset + 1200 )) -l 4 "$1"
#	echo "Data size end"

#increment vars for next loop
	((bank++))
	nhcd=$((nhcd+512))
	offset=$((offset+4707319808))
#clear vars
	wiimagic=""
	gcmagic=""
	gamesize=""
	type=""
  printf '\n'
  printf '\n'
done

}


undelete(){
#Determine if a bank is deleted.
#If deleted, check to see if disc header is missing.
#If it's missing, copy it from the game partition
#add entry to NHCD, making sure it matches game (wii or gc) and size (1 layer or 2)


nhcd=1610613248
header_location=0
bank=$2
bank_type=""
dual_layer=""
deleted=0
offset=$(( 1610617344+((bank-1)*4707319808) ))
header_present=0

# determine the offset of the header entry specified by $2. 
header_location=$(( (((bank-1)*512)+$nhcd) ))

wiimagic=$(xxd -s $(( offset+24 )) -l 4 -p $1)
gcmagic=$(xxd -s $(( offset+28 )) -l 4 -p $1)

# put the value from the header into $header_location. This will be null if the bank is deleted
bank_type=$(dd if=$1 bs=1 skip=$header_location count=4 status=none | tr -d '\0\n')

# if bank is deleted, $bank_type will be null
if [[ -z "$bank_type" ]]; then
     #This checks the previous partition to see if the current partition is part of a dual layer game
   dual_layer=$(dd if=$1 bs=1 skip=$(( (header_location-512) )) count=4 status=none | tr -d '\0\n')
	if [[ "$dual_layer" == "NN2L" ]]; then
		echo "Bank $bank is likely part of the dual layer disc in bank $(( (bank-1) ))."
		deleted=0
	else
		echo "This bank is deleted #extra line"
		deleted=1
	fi

	# check for disc header here. If it's missing, check further down the disc. Only test with unencrytped disc
	else
	echo "This bank is not deleted #extra line"
	deleted=0
fi

	# if bank is deleted ($deleted = 1), then check for a disc header

	if [[ "$deleted" = 1 ]]; then
		#check for presence of a disc header
		header_present=$(dd if=$1 bs=512 skip=$offset count=1 status=none | strings)
#		if [[ -z "$header_present" ]]; then
#			echo "Header Missing. Cannot be restored by this version of r3d-dwarf."
		if [[ "$wiimagic" == "5d1c9ea3" && "$gcmagic" == "00000000" ]]; then
			echo "Wii Game NHCD Header needs restored. Dual layer discs may cause an issue."
		elif [[ "$gcmagic" == "c2339f3d" && "$wiimagic" == "00000000" ]]; then
			echo "Gamecube Game NHCD Header needs restored."
		else
		echo "Error. Debug 3. Are you in the middle of a dual layer disc?"
	fi
fi




echo $header_location
echo $bank
echo $bank_type "banktype"
echo $wiimagic
echo $gcmagic
echo $offset

#undeleted_yn=$(dd if=$1 bs=1 skip=$nhcd count=4 status=none | tr -d '\0\n')

}


case "$1" in
    list|-l)
        listbanks "$2"
        ;;
     restore|-r)
        undelete "$2" "$3"
        ;;
  #  listall|-la)
#	numlistall "$2"
#	;;
 #   extractall|-xa)
#	bankextractall "$2"
#	;;
	help|--h|-h)
	echo This is a VERY beta tool for analyzing RVT H HDDs.
	echo use $0 -l to list banks. This will struggle with deleted 2 layer banks and with missing disc headers.
	exit 1
	;;

	*)
        echo run $0 -h for usage instructions
        exit 1
        ;;
esac
