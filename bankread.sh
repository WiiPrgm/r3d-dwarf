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
  gcmagic=$(xxd -s $(( offset+28 )) -l 4 -p "$1")
  is_dual_layer=""
  gamesize=""
  crypt=""

  cryptprobe=$(dd if="$1" bs=1 skip=$(( $offset+96 )) count=4 status=none | tr -d '\0\n' | xxd -p)
  firstpartoffset=$(( 0x$(xxd -s $(( offset+262176 )) -l 4 -p "$1") *4 ))
  secondpartoffset=$((  0x$(xxd -s $(( offset+262184 )) -l 4 -p "$1") *4 ))
secondpartdatastart=$(( 0x$(xxd -s $(( offset+secondpartoffset+696 )) -l 4 -p "$1") *4 ))
  unenc_bankstart=$(( offset+secondpartoffset+secondpartdatastart ))
second_wiimagic=$(xxd -s $(( unenc_bankstart + 24 )) -l 4 -p "$1")
cert_check=$(dd if="$1" bs=1 skip=$(( offset+secondpartoffset+320 )) count=4 status=none | tr -d '\0\n' )

enc_check=""


#Read game type from NHCD header. This will be blank if entry is deleted
	type=$(dd if=$1 bs=1 skip=$nhcd count=4 status=none | tr -d '\0\n')

	case "$type" in
		NN1L) gamesize="Single Layer" ;;
		GC1L) gamesize="Gamecube Game" ;;
		NN2L) gamesize="Dual Layer"
			offset=$((offset+4707319808))
			is_dual_layer=1
			nhcd=$((nhcd+512))
    			;;
		""|*) gamesize=""
			type="Deleted"
    			;;
	esac


#check game type against magic word in disc image
	if [[ "$wiimagic" == "5d1c9ea3" && "$gcmagic" == "00000000" ]]; then
		if [[ $type == NN* ]]; then
			gametype="Wii Game"
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
		elif [[ "$type"="Deleted" ]]; then
			gametype="Deleted Gamecube Game with header. (Easy to recover.)"
		elif [[ $type == NN* ]]; then
			gametype="Error. NHCD header says Wii, but disc image doesn't match."
		else
			gametype="ERROR. Debug 2. How did you get here?"
		fi
	elif [[ "$gcmagic" == "00000000" && "$wiimagic" == "00000000" && "$type" == "Deleted" ]]; then
		gametype="Deleted Bank. NHCD entry is blank and disc header is missing."
			if [[ "$second_wiimagic" == "5d1c9ea3" ]]; then
				enc_check="Disc is unencrypted. Disc header can be easily restored."
				currentbankid=$(dd if="$1" bs=1 skip="$unenc_bankstart" count=6 status=none | strings)
				currentbankname=$(dd if="$1" bs=1 skip=$(( unenc_bankstart+6 )) count=64 status=none | strings | sed 's/^=//')
			elif [[ "$cert_check" = "Root" ]]; then
				enc_check="Disc is encrypted. Fake header is needed."
			else
				enc_check="Disc type unknown. Unable to restore at this time."
			fi

#add logic if there are no magic words and no header entry. try to check for presence of a disc
	else
		gametype="Invalid Header Data. This might be the second partiton of a deleted dual layer game."
		currentbankid=""
		currentbankname=""
fi

#encryption type
	if [[ "$cryptprobe" == "0101" ]]; then
		crypt="Unencrypted"
	else
		crypt=""
	fi

        echo "Bank "$bank":"
	[[ -n "$currentbankid" ]] && echo "Game ID:" "$currentbankid"
	[[ -n "$currentbankname" ]] && echo "Game Name:" "$currentbankname"
	[[ -n "$gamesize" && "$gamesize" != "Gamecube Game" ]] && echo "$gamesize"
	[[ -n "$crypt" ]] && printf '%s ' "$crypt"; printf '%s\n' "$gametype"
#	[[ -n "$crypt" ]] && echo "$crypt"; printf '%s\n' "$gametype"
	#echo $gametype
	[[ -n "$enc_check" ]] && echo "$enc_check"

#increment vars for next loop
	((bank++))
		if [[ -n "$is_dual_layer" ]]; then
    			((bank++))
		fi
	nhcd=$((nhcd+512))
	offset=$((offset+4707319808))
#clear vars
	wiimagic=""
	gcmagic=""
	gamesize=""
	type=""
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
next_bank_offset=$(( 1610617344+((bank)*4707319808) ))

header_present=0
secondpartoffset=$(( 0x$(xxd -s $(( offset+262184 )) -l 4 -p "$1") *4 ))
secondpartdatastart=$(( 0x$(xxd -s $(( offset+secondpartoffset+696 )) -l 4 -p "$1" 2> /dev/null) *4 ))
unenc_bankstart=$(( offset+secondpartoffset+secondpartdatastart ))
cert_check=$(dd if="$1" bs=1 skip=$(( offset+secondpartoffset+320 )) count=4 status=none | tr -d '\0\n' )
cryptprobe=$(dd if="$1" bs=1 skip=$(( $offset+96 )) count=4 status=none | tr -d '\0\n' | xxd -p)

second_wiimagic=$(xxd -s $(( unenc_bankstart + 24 )) -l 4 -p "$1")
needs_disc_header=0

# determine the offset of the header entry specified by $2.
header_location=$(( (((bank-1)*512)+$nhcd) ))

wiimagic=$(xxd -s $(( offset+24 )) -l 4 -p $1)
gcmagic=$(xxd -s $(( offset+28 )) -l 4 -p $1)
next_bank_wiimagic=$(xxd -s $(( next_bank_offset+24 )) -l 4 -p $1)
next_bank_gcmagic=$(xxd -s $(( next_bank_offset+28 )) -l 4 -p $1)


no_nhcd_header=0
no_disc_header=0
is_encrypted=1

# put the value from the header into $header_location. This will be null if the bank is deleted
bank_type=$(dd if=$1 bs=1 skip=$header_location count=4 status=none | tr -d '\0\n')

echo "$cert_check" "cert"

#Step 1. Check to see if bank is actually deleted.

# if bank is deleted, $bank_type will be null
if [[ -z "$bank_type" ]]; then
     #This checks the previous partition to see if the current partition is part of a dual layer game
   dual_layer=$(dd if=$1 bs=1 skip=$(( (header_location-512) )) count=4 status=none | tr -d '\0\n')
	if [[ "$dual_layer" == "NN2L" ]]; then
		echo "Bank $bank is likely part of the dual layer disc in bank $(( (bank-1) )) and does not need restored"
		exit 0
	else
		deleted=1
		no_nhcd_header=1
	fi

	# check for disc header here. If it's missing, check further down the disc. Only test with unencrytped disc
	else
		echo "This bank is not deleted and does not need restored."
		exit 0
fi

#Step 2. Check to see if the disc at $bank is wii or gamecube, or if the disc header was blanked.


	if [[ "$deleted" = 1 ]]; then
		if [[ "$wiimagic" == "5d1c9ea3" && "$gcmagic" == "00000000" ]]; then
			echo "Wii Game NHCD Header needs restored."
			#wii=1
		elif [[ "$gcmagic" == "c2339f3d" && "$wiimagic" == "00000000" ]]; then
			echo "Gamecube Game NHCD Header needs restored."
			#gamecube=1
			disc_layer_guess="GC1L"
			hex_size="002bbac0"
		elif [[ "$gcmagic" == "00000000" && "$wiimagic" == "00000000" ]]; then
		#	echo "Error. Debug 3. NHCD Missing and no disc header?"
				no_disc_header=1
				if [[ "$second_wiimagic" == "5d1c9ea3" ]]; then
					echo "Disc header missing. To restore, copy header from unencrypted wii partition"
					unenc_wii=1
				elif [[ "$cert_check" == "Root" ]]; then
					echo "Disc header missing. To restore, copy header from encrypted partition"
					enc_wii=1
				else
					echo "Error. Possible Gamecube game with empty header detected. Cannot be recovered by this version of r3d-dwarf."
				fi
		else
			echo "Error. No recoverable data found."
			junk_data=1
			exit 1
		fi
	fi


#check for presence of unencrypted header or encrypted TMD if no header is found.

#	if [[ "$no_disc_header" == "1" ]]; then
#		if [[ "$second_wiimagic" == "5d1c9ea3" ]]; then
#			echo "To restore, copy header from unencrypted wii partition"
#			unenc_wii=1
#		else
#		if [[ "$cert_check" == "Root" ]]; then
#			echo "To restore, copy header from encrypted partition"
#			enc_wii=1
#		fi
#	fi

#if unenc_wii=1. copy header from start of disc

#check the next bank for Wii and GC magic (or zeros, indicating a deleted bank)
	if [[ "$disc_layer_guess" != "GC1L" ]]; then
		echo "$disc_layer_guess"
		if [[ "$next_bank_wiimagic" == "5d1c9ea3" || "$next_bank_gcmagic" == "c2339f3d" || ("$next_bank_gcmagic" == "00000000" && "$next_bank_wiimagic" == "00000000") ]]; then
			echo "Current bank is likely single layer."
			disc_layer_guess=NN1L
			hex_size="008c4a00"
		else
			echo "No valid data in next bank. Assuming dual layer."
			disc_layer_guess=NN2L
			hex_size="00ee0000"
		fi
	fi

#parts of nhcd header:
#1. gametype (gc, nn1l, nn2l)       4 bytes
#2. 14 zeros
#3. 14 char ascii timestamp
#4. staring lba <based on banknum
#5. length (based on 1l 2l or gc
#6 meaningless empty bytes to next bank entry

hexoffset=$(( 3145737+$(( 9193984*($bank-1) )) ))

pad="00000000000000"
date="$(date +%Y%m%d%H%M%S)"

	if [[ "$no_nhcd_header" = "1" ]]; then

		printf '%s' "$disc_layer_guess""$pad""$date" #| dd of=$1 bs=1 seek=$nhcd conv=notrunc status=none

		echo "hex offset"
		printf '%08x' "$hexoffset" #| xxd -r -p #| dd of=$1 bs=1 seek=$(( nhcd+20 )) conv=notrunc status=none
		echo "hex size"
		printf '%s\n' "$hex_size" #| xxd -r -p #| dd of=$1 bs=1 seek=$(( nhcd+24 )) conv=notrunc status=none

	fi
#	if [[ "$no_disc_header" = 0 && "$wii" = 1 ]]; then
#		#printf stuff | dd
#
#		$(( date +"%Y%m%d%H%M%S" )) + "000000000000000000" + 
#
#	elif [[ "$no_disc_header" = 0 && "$gamecube" = 1 ]]l then
#		#printf other stuff | dd
#	fi
#	fi

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
