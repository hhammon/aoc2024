cd "$(dirname "$0")"
set -e

as -o utils.o utils.s
as -o create-lists.o create-lists.s
as -o part1.o part1.s
as -o part2.o part2.s

mkdir -p bin

ld -o bin/part1 part1.o create-lists.o utils.o
ld -o bin/part2 part2.o create-lists.o utils.o

rm *.o

echo "Day 1 (Amity)"

echo "Running Part 1 on sample input."
./bin/part1 input/sample.txt

echo "Running Part 1 on puzzle input."
./bin/part1 input/input.txt

echo "Running Part 2 on sample input."
./bin/part2 input/sample.txt

echo "Running Part 2 on puzzle input."
./bin/part2 input/input.txt
