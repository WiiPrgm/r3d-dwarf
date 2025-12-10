#
offset=1610617344
bank=1
nhcd=1610613248
type=""
header_present=""
currentbankid=""
currentbankname=""
gamesize=""
gcmagic=""
wiimagic=""


while (( bank <= 8 )); do

  currentbankid=$(dd if=$1 bs=1 skip=$offset count=6 status=none | strings)
  currentbankname=$(dd if=$1 bs=1 skip=$(( offset+6 )) count=64 status=none | strings | sed 's/^=//')
  wiimagic=$(xxd -s $(( offset+24 )) -l 4 -p $1)
  gcmagic=$(xxd -s $(( offset+28 )) -l 4 -p $1)
  gamesize=""

#Read game type from NHCD header. This will be blank if entry is deleted
	type=$(dd if=$1 bs=1 skip=$nhcd count=4 status=none | tr -d '\0\n')
#Determine game size based on NHCD header entry

	if [[ "$type" == "NN1L" ]]; then
		gamesize="Single Layer"
	elif [[ "$type" == "GC1L" ]]; then
		gamesize="Gamecube Game"
	elif [[ "$type" == "NN2L" ]]; then
		gamesize="Dual Layer"

#increment vars since dual layer games take up two banks
		offset=$((offset+4707319808))
		((bank++))
		nhcd=$((nhcd+512))
	else
		gamesize="Deleted Bank"
		type="Deleted"
	fi

	#offset=$((offset+4707319808))

#displays stats if vars aren't empty.

	echo "Bank "$bank":"
	[[ -n "$currentbankid" ]] && echo "$currentbankid"
	[[ -n "$currentbankname" ]] && echo "$currentbankname"
	#echo "$gamesize"; gamesize=""


#check game type against magic word in disc image
	if [[ "$wiimagic" == "5d1c9ea3" && "$gcmagic" == "00000000" ]]; then
		if [[ $type == NN* ]]; then
			gametype="Wii Game"
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
	#add logic if there are no magic words and no header entry. try to check for presence of a disc
	else
		gametype="Garbage Data Detected. This might be the second partiton of a deleted dual layer game."

fi

echo $gametype

#increment vars for next loop
	((bank++))
	nhcd=$((nhcd+512))
	offset=$((offset+4707319808))
#clear vars
	wiimagic=""
	gcmagic=""
	header_present=""

  printf '\n'
  printf '\n'
done
