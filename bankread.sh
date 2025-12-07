offset=3145737
bank=1
nhcd=1610613248

for run in {1..8}; do
  echo "Bank "$bank":"
  ((bank++))
  dd if=$1 bs=512 skip=$offset count=1 status=none | strings
  #printf '\n'
  offset=$((offset+9193984))

  dd if=$1 bs=1 skip=$nhcd count=4 status=none
  nhcd=$((nhcd+512))
  printf '\n'
  printf '\n'
done
