#!/bin/bash

#ARG 1: local repo (will be copied in /tmp)

BENCHPR="BENCHPR"
NAME="algebraic-graphs"

echo "SETTING UP..."

{
rm -rf /tmp/$BENCHPR
mkdir /tmp/$BENCHPR

git clone https://github.com/haskell-perf/graphs /tmp/$BENCHPR/graphs 

cp -r $1 /tmp/$BENCHPR/graphs/alga

pushd /tmp/$BENCHPR/graphs

git clone https://github.com/snowleopard/alga.git old

# Will transofrm the actual alga in a package "old", exporting "Algebra.GraphOld"
cd old
sed -i "s/$NAME/old/g" $NAME.cabal
sed -i "s/Algebra.Graph,/Algebra.GraphOld,/g" $NAME.cabal
mv $NAME.cabal old.cabal
mv src/Algebra/Graph.hs src/Algebra/GraphOld.hs
find . -type f -iname '*.hs' -exec sed -i "s/Algebra.Graph[^.]/Algebra.GraphOld/g" "{}" +;
cd ..

sed -i '/^\s*$/d' stack.yaml
sed -i "s/extra-deps:/  - old\n  - alga\nextra-deps:/g" stack.yaml
sed -i "s|.*git: https://github.com/snowleopard/alga.git||g" stack.yaml
sed -i "s/commit: 64e4d908c15d5e79138c6445684b9bef27987e8c//g" stack.yaml

sed -i "s/Alga.Graph/Alga.Graph,Alga.GraphOld/g" bench-graph.cabal
sed -ri "s/$NAME(.*)/old, $NAME,/g" bench-graph.cabal

cp bench/Alga/Graph.hs bench/Alga/GraphOld.hs

sed -i "s/Alga.Graph/Alga.GraphOld/g" bench/Alga/GraphOld.hs
sed -i "s/Algebra.Graph/Algebra.GraphOld/g" bench/Alga/GraphOld.hs

sed -i "s/import qualified Alga.Graph/import qualified Alga.Graph\nimport qualified Alga.GraphOld/g" bench/ListS.hs
sed -i "s/(\(\"Alga\", map Shadow Alga.Graph.functions \))/\(\1\),\(\"AlgaOld\", map Shadow Alga.GraphOld.functions \)/g" bench/ListS.hs

} &> /dev/null

echo "BUILDING..."

stack build "bench-graph:bench:time" --no-run-benchmarks 

STR=""

ARGS="$@"
ARGS=$(echo $ARGS | cut -d' ' -f2-)

for var in $ARGS
do
	STR="$STR --only $var"
done

echo "RUNNING..."

.stack-work/dist/*/*/build/time/time run -l Alga -l AlgaOld $STR

popd
