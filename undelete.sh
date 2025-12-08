#Determine if a bank is deleted.
#If deleted, check to see if disc header is missing.
#If it's missing, copy it from the game partition
#add entry to NHCD, making sure it matches game (wii or gc) and size (1 layer or 2)

#undeleted_yn=""
nhcd=1610613248
header_location=0
bank=$2
bank_type=""
dual_layer=""
deleted=0
offset=3145737
header_present=0

# determine the offset of the header entry specified by $2. 
header_location=$(( (((bank-1)*512)+$nhcd) ))


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
		echo "This bank is deleted"
		deleted=1
	fi

	# check for disc header here. If it's missing, check further down the disc. Only test with unencrytped disc
else
	echo "This bank is not deleted"
	deleted=0
fi

	# if bank is deleted ($deleted = 1), then check for a disc header

	if [[ "$deleted" = 1 ]]; then
		#check for presence of a disc header
		header_present=$(dd if=$1 bs=512 skip=$offset count=1 status=none | strings)
		if [[ -z "$header_present" ]]; then
			echo "Header Missing. Will need restored."
		else
			echo "Header is present. Bank can be restored easily."
		fi

	else
		echo "Bank does not need undeleted"
	fi





echo $header_location
echo $bank
echo $bank_type


#undeleted_yn=$(dd if=$1 bs=1 skip=$nhcd count=4 status=none | tr -d '\0\n')
