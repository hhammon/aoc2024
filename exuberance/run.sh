cd "$(dirname "$0")"
set -e

as -o utils.o utils.s
as -o list-pages.o list-pages.s
as -o rule-set.o rule-set.s
as -o part1.o part1.s
as -o part2.o part2.s

mkdir -p bin

ld -o bin/part1 part1.o rule-set.o list-pages.o utils.o
ld -o bin/part2 part2.o rule-set.o list-pages.o utils.o

rm *.o

echo "Day 5 (Exuberance)"

echo "Running Part 1 on sample input."
./bin/part1 input/sample.txt

echo "Running Part 1 on puzzle input."
./bin/part1 input/input.txt

echo "Running Part 2 on sample input."
./bin/part2 input/sample.txt

echo "Running Part 2 on puzzle input."
./bin/part2 input/input.txt