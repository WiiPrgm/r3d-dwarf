offset=3145737
bank=1

for run in {1..8}; do
  echo "Bank "$bank":"
  ((bank++))
  dd if=$1 bs=512 skip=$offset count=1 status=none | strings
  printf '\n'
offset=$((offset+9193984))
done
