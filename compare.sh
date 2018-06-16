#!/bin/bash

#ARG 1: Stack or Cabal
#ARG 2: local repo (will be copied in /tmp)
#ARG 3: Output: Html or Ascii
#ARG 4: COMMIT ID to rest alga
#Other Args: Functions to benchmark

BENCHPR="BENCHPR"
NAME="algebraic-graphs"
BGVERSION="bench-graph-0.1.0.0"

if [ "$#" -lt 4 ]; then
    echo "You must enter more than 4 command line arguments"
    exit 1
fi

{
rm -rf /tmp/$BENCHPR
mkdir /tmp/$BENCHPR

git clone https://github.com/haskell-perf/graphs /tmp/$BENCHPR/graphs 

cp -r $2 /tmp/$BENCHPR/graphs/alga

pushd /tmp/$BENCHPR/graphs

git clone https://github.com/snowleopard/alga.git old

# Will transofrm the actual alga in a package "old", exporting "Algebra.GraphOld"
cd old
git reset --hard $4
sed -i "s/$NAME/old/g" $NAME.cabal
sed -i "s/Algebra.Graph,/Algebra.GraphOld,/g" $NAME.cabal
mv $NAME.cabal old.cabal
mv src/Algebra/Graph.hs src/Algebra/GraphOld.hs
find . -type f -iname '*.hs' -exec sed -i "s/Algebra.Graph[^.]/Algebra.GraphOld/g" "{}" +;
cd ..

if [ $1 = "Stack" ]
then
sed -i '/^\s*$/d' stack.yaml
sed -i "s/extra-deps:/  - old\n  - alga\nextra-deps:/g" stack.yaml
sed -i "s|.*git: https://github.com/snowleopard/alga.git||g" stack.yaml
sed -i "s/commit: 64e4d908c15d5e79138c6445684b9bef27987e8c//g" stack.yaml
else
echo "packages: \".\" old/ alga/" > cabal.project
fi

sed -i "s/Alga.Graph/Alga.Graph,Alga.GraphOld/g" bench-graph.cabal
sed -ri "s/$NAME(.*)/old, $NAME\1/g" bench-graph.cabal

cp bench/Alga/Graph.hs bench/Alga/GraphOld.hs

sed -i "s/Alga.Graph/Alga.GraphOld/g" bench/Alga/GraphOld.hs
sed -i "s/Algebra.Graph/Algebra.GraphOld/g" bench/Alga/GraphOld.hs

sed -i "s/import qualified Alga.Graph/import qualified Alga.Graph\nimport qualified Alga.GraphOld/g" bench/ListS.hs
sed -i "s/(\(\"Alga\", map Shadow Alga.Graph.functions \))/\(\1\),\(\"AlgaOld\", map Shadow Alga.GraphOld.functions \)/g" bench/ListS.hs

sed -i "s/import qualified Alga.Graph/import qualified Alga.Graph\nimport qualified Alga.GraphOld/g" bench/Time.hs
sed -i "s/(\(\"Alga\", benchmarkCreation gr Alga.Graph.mk \))/\(\1\),\(\"AlgaOld\", benchmarkCreation gr Alga.GraphOld.mk \)/g" bench/Time.hs

} &> /dev/null

if [ "$1" = "Stack" ]
then
  stack build "bench-graph:bench:time" --no-run-benchmarks 
else
  cabal -f -Datasize -f -Space -f -Fgl -f -HashGraph new-build time --enable-benchmarks
fi

STR=""

ARGS=$(echo "$@" | cut -d' ' -f5-)

for var in $ARGS
do
	STR="$STR --only $var"
done

CMDARGS="run -d $3 -l Alga -l AlgaOld $STR"

echo $CMDARGS

if [ "$1" = "Stack" ]
then
  .stack-work/dist/*/*/build/time/time $CMDARGS 0>&0
else
  ./dist-newstyle/build/x86_64-linux/*/$BGVERSION/build/time/time $CMDARGS 0>&0
fi
popd
