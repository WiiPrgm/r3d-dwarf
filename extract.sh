if (( "$2" < 0 || "$2" > 8 )); then
    echo "Error: Bank number must be between 1 and 8"
    exit 1
fi

nhcd=1610613248 #bs=1
header_location=0
bank=$2
bank_type=""
dual_layer=""
deleted=0
offset=$(( (3145737+((bank-1)*9193984)) )) #bs=512
offset_dec=$(( 1610617344+((bank-1)*4707319808) )) #bs=1
header_present=0
wii_single_layer=9193984 #bs=512
wii_dual_layer=15597568 #bs=512
gc_size=2865856 #bs=512
# determine the offset of the header entry specified by $2.
header_location=$(( (((bank-1)*512)+$nhcd) )) #bs=1
hiddenbankname="$(dd if="$1" bs=1 count=64 skip=8 status=none | strings)"

if [[ "$bank" -eq 0 ]]; then
	echo "Extracting hidden ban: "$hiddenbankname""
	echo "Assuming single layer..."
	dd if="$1" of="$hiddenbankname"".""$1".iso bs=512 skip=0 count="$wii_single_layer"
	exit 0
fi

# put the value from the header into $header_location. This will be null if the bank is deleted
bank_type=$(dd if="$1" bs=1 skip=$header_location count=4 status=none | tr -d '\0\n')

# if bank is deleted, $bank_type will be null
if [[ -z "$bank_type" ]]; then
     #This checks the previous partition to see if the current partition is part of a dual layer game
   dual_layer=$(dd if="$1" bs=1 skip=$(( (header_location-512) )) count=4 status=none | tr -d '\0\n')
	if [[ "$dual_layer" == "NN2L" ]]; then
		echo "Bank $bank is likely part of the dual layer disc in bank $(( (bank-1) ))."
		echo "Please extract that bank instead."
    exit 1
	else
		echo "This bank is deleted. Please restore this bank before extracting. (Not available in this version of r3d-dwarf.)"
		exit 1
	fi
	# check for disc header here. If it's missing, check further down the disc. Only test with unencrytped disc
	else
  	# store game name in a variable for later
  	currentbankname=$(dd if="$1" bs=1 skip=$(( offset_dec+6 )) count=64 status=none | strings | sed 's/^=//')
fi

	# if bank is deleted ($deleted = 1), then check for a disc header

	case "$bank_type" in
		NN1L)
		echo "Extracting $currentbankname"
		dd if="$1" of="$currentbankname".iso bs=512 skip="$offset" count="$wii_single_layer"
		;;
	GC1L)
		echo "Extracting $currentbankname"
		dd if="$1" of="$currentbankname".iso bs=512 skip="$offset" count="$gc_size"
		;;
	NN2L)
		echo "Extracting $currentbankname"
		dd if="$1" of="$currentbankname".iso bs=512 skip="$offset" count="$wii_dual_layer"
		;;
	""|*)
		echo "Something terrible has happened. Debug 7."
    		;;
	esac



#echo $currentbankname
#echo $header_location
#echo $bank
#echo $bank_type "banktype"
#echo $wiimagic
#echo $gcmagic
#echo $offset

#undeleted_yn=$(dd if=$1 bs=1 skip=$nhcd count=4 status=none | tr -d '\0\n')
