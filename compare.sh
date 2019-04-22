#!/bin/bash

# TODO switch to PackageImports everywhere

BENCHDIR=$(mktemp -d)
NAME="algebraic-graphs"
BGVERSION="bench-graph-0.1.0.0"

if [ "$1" == "help" ]; then
    echo "Usage:"
    echo "./compare.sh A B C D [E F [...]]"
    echo "A: 'Stack' or the path of the cabal binary"
    echo "B: local repo"
    echo "C: 'Html', 'Ascii' or 'QuickComparison'"
    echo "D: Commit ID"
    echo "E: [OPTIONAL] If 'True', will benchmark NonEmpty graphs"
    echo "F [...]: [OPTIONAL] Particular functions to benchmark"
    echo "\n You can set the HC variable to specify a specific path for GHC"
    exit 1
fi

if [ "$#" -lt 4 ]; then
    echo "You must enter more than 3 command line arguments"
    echo "'./compare.sh help' for help"
    exit 1
fi

if [ "$5" = "True" ]
then
  FILE="Algebra/Graph/NonEmpty.hs"
else
  FILE="Algebra/Graph.hs"
fi

FILEHS=$(echo "$FILE" | sed 's/.\{3\}$//' | sed 's|/|.|g')

git clone -q https://github.com/haskell-perf/graphs $BENCHDIR/graphs

cp -r $2 $BENCHDIR/graphs/alga

pushd $BENCHDIR/graphs/alga &> /dev/null

echo "Alga Commit ID: $(git rev-parse HEAD)"
cd ..

git clone -q https://github.com/snowleopard/alga.git old

# Will transofrm the actual alga in a package "old"
cd old
git reset --hard $4

echo "AlgaOld Commit ID: $(git rev-parse HEAD)"

sed -i "s/$NAME/old/g" $NAME.cabal
mv $NAME.cabal old.cabal

cd ..

if [ $1 = "Stack" ]
then
sed -i '/^\s*$/d' stack.yaml
sed -i "s/extra-deps:/  - old\n  - alga\nextra-deps:/g" stack.yaml

# Remove unecessary extra-deps
sed -i "s|.*git:.*||g" stack.yaml
sed -i "s/.*commit:.*//g" stack.yaml

else
echo "packages: \".\" old/ alga/" > cabal.project
fi

# Copy benchmarks files
sed -i "s/$FILEHS/$FILEHS,${FILEHS}Old/g" bench-graph.cabal
sed -ri "s/$NAME(.*)/old, $NAME\1/g" bench-graph.cabal

cp bench/Alga/Graph.hs bench/Alga/GraphOld.hs

for n in "bench/Alga/Graph.hs" "bench/Alga/GraphOld.hs"
do
  sed -i '1 i\{-# LANGUAGE PackageImports #-}' $n
done

sed -i "s/import Algebra.Graph/import \"$NAME\" Algebra.Graph/g" bench/Alga/Graph.hs
sed -i "s/import Algebra.Graph/import \"old\" Algebra.Graph/g" bench/Alga/GraphOld.hs
sed -i "s/module Alga.Graph/module Alga.GraphOld/g" bench/Alga/GraphOld.hs

sed -i "s/import qualified Algebra.Graph.AdjacencyIntMap as AIM/import qualified \"$NAME\" Algebra.Graph.AdjacencyIntMap as AIM/" bench/Alga/Graph.hs
sed -i "s/import qualified Algebra.Graph.AdjacencyIntMap as AIM/import qualified \"old\" Algebra.Graph.AdjacencyIntMap as AIM/" bench/Alga/GraphOld.hs

sed -i "s/import qualified Algebra.Graph.AdjacencyIntMap.Algorithm as AIM/import qualified \"$NAME\" Algebra.Graph.AdjacencyIntMap.Algorithm as AIM/" bench/Alga/Graph.hs
sed -i "s/import qualified Algebra.Graph.AdjacencyIntMap.Algorithm as AIM/import qualified \"old\" Algebra.Graph.AdjacencyIntMap.Algorithm as AIM/" bench/Alga/GraphOld.hs

# If we benchmark NonEmpty
if [ "$5" = "True" ]
then
  for n in "bench/Alga/Graph.hs" "bench/Alga/GraphOld.hs"
  do
    sed -i "s/import BenchGraph.Types/import BenchGraph.Types\nimport qualified Data.List.NonEmpty as L/" $n
    sed -i 's/Algebra.Graph$/Algebra.Graph.NonEmpty/g' $n
    sed -i 's/mk = edges/mk = edges1 . L.fromList/' $n
    sed -i 's/clique/clique1 $ L.fromList/g' $n
    sed -i 's/.*isEmpty.*//g' $n
    sed -i 's/ vertexList/ vertexList1/g' $n
    sed -i  's/ removeVertex/ removeVertex1/g' $n
    sed -i  's/ foldg AIM.empty/ foldg1/g' $n
  done
  sed -i "s/\"creation\"/\"edges1\"/g" src/BenchGraph/Time.hs


  sed -i "s/\"vertexList\"/\"vertexList1\"/g" src/BenchGraph/Suites.hs
  sed -i "s/\"removeVertex\"/\"removeVertex1\"/g" src/BenchGraph/Suites.hs
else
  sed -i "s/\"creation\"/\"edges\"/g" src/BenchGraph/Time.hs
fi

sed -i "s/import qualified Alga.Graph/import qualified Alga.Graph\nimport qualified Alga.GraphOld/g" bench/ListS.hs
sed -i "s/(\(\"Alga\", map Shadow Alga.Graph.functions \))/\(\1\),\(\"AlgaOld\", map Shadow Alga.GraphOld.functions \)/g" bench/ListS.hs

sed -i "s/import qualified Alga.Graph/import qualified Alga.Graph\nimport qualified Alga.GraphOld/g" bench/Time.hs
sed -i "s/(\(\"Alga\", Right $ benchmarkCreation dontBenchLittleOnes gr Alga.Graph.mk \))/\(\1\),\(\"AlgaOld\", Right $ benchmarkCreation dontBenchLittleOnes gr Alga.GraphOld.mk \)/g" bench/Time.hs

# Output something every 5 minutes or Travis kills the job
echo ""
echo "Install dependencies and build the benchmarking suite"
while sleep 300; do echo "> Still running..."; done &

if [ "$1" = "Stack" ]
then
  stack build "bench-graph:bench:time" --no-run-benchmarks --flag "bench-graph:-reallife" --flag "bench-graph:-datasize" --flag "bench-graph:-space" --flag "bench-graph:-fgl"  --flag "bench-graph:-hashgraph" --flag "bench-graph:-chart" &> /dev/null
else
  $1 new-build time $(if [ "$HC" != "" ]; then echo "-w $HC"; else echo ""; fi;) --enable-benchmarks -f -Datasize -f -Space -f -Fgl -f -HashGraph -f -RealLife -f -Chart -f Time -f Alga -f AlgaOld &> /dev/null
fi

exec 3>&2
exec 2> /dev/null

kill "%1"

STR=""

ARGS=$(echo "$@" | cut -d' ' -f6-)

for var in $ARGS
do
	STR="$STR --only $var"
done

# Drop some benchs, only if we don't require explicitly them
if [ "$STR" = "" ]
then
  DROPPED=""
else
  DROPPED="-n dff -n topSort"
fi

CMDARGS="run -g (\"Mesh\",3) -g (\"Clique\",3) -g (\"Circuit\",3) -i -d $3 -l Alga -l AlgaOld $DROPPED $STR"

echo ""
echo "Args: $CMDARGS"

if [ "$1" = "Stack" ]
then
  .stack-work/dist/*/*/build/time/time $CMDARGS 0>&0
else
  $1 new-run time $(if [ "$HC" != "" ]; then echo "-w $HC"; else echo ""; fi;) --enable-benchmarks -f -Datasize -f -Space -f -Fgl -f -HashGraph -f -RealLife -f -Chart -f Time -f Alga -f AlgaOld --ghc-options=-dynamic -- $CMDARGS 0>&0
fi
popd

rm -rf $BENCHDIR
