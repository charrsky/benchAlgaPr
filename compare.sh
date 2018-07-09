#!/bin/bash

#ARG 1: Stack or Cabal
#ARG 2: local repo (will be copied in /tmp)
#ARG 3: Output: Html, Ascii or QuickComparison
#ARG 4: COMMIT ID to reset alga
#ARG 5: (Optional, needed if trying to bench specific functions (see below))If set to "True", will bench Alga.Graph.NonEmpty instead of Alga.Graph
#Other Args: Functions to benchmark

BENCHPR="BENCHPR"
NAME="algebraic-graphs"
BGVERSION="bench-graph-0.1.0.0"

if [ "$#" -lt 4 ]; then
    echo "You must enter more than 3 command line arguments"
    exit 1
fi

if [ "$5" = "True" ]
then
  FILE="Algebra/Graph/NonEmpty.hs"
else
  FILE="Algebra/Graph.hs"
fi

FILEHS=$(echo "$FILE" | sed 's/.\{3\}$//' | sed 's|/|.|g')

rm -rf /tmp/$BENCHPR
mkdir /tmp/$BENCHPR

git clone https://github.com/haskell-perf/graphs /tmp/$BENCHPR/graphs 

cp -r $2 /tmp/$BENCHPR/graphs/alga

pushd /tmp/$BENCHPR/graphs/alga

echo "Alga Commit ID: $(git rev-parse HEAD)"
cd ..

git clone https://github.com/snowleopard/alga.git old

# Will transofrm the actual alga in a package "old", exporting "Algebra.GraphOld"
cd old
git reset --hard $4

echo "AlgaOld Commit ID: $(git rev-parse HEAD)"

sed -i "s/$NAME/old/g" $NAME.cabal
mv $NAME.cabal old.cabal

for n in "Algebra/Graph.hs" "Algebra/Graph/NonEmpty.hs"
do
  nPrime=$(echo "$n" | sed 's/.\{3\}$//' | sed 's|/|.|g')
  sed -i "s/$nPrime,/${nPrime}Old,/g" old.cabal
  mv "src/$n" "src/$(echo "$n" | sed 's/.\{3\}$//')Old.hs"
  find . -type f -iname '*.hs' -exec sed -i "s/$nPrime[^.]/${nPrime}Old/g" "{}" +;
done

cd ..

if [ $1 = "Stack" ]
then
sed -i '/^\s*$/d' stack.yaml
sed -i "s/extra-deps:/  - old\n  - alga\nextra-deps:/g" stack.yaml
sed -i "s|.*git:.*||g" stack.yaml
sed -i "s/.*commit:.*//g" stack.yaml
else
echo "packages: \".\" old/ alga/" > cabal.project
fi

sed -i "s/$FILEHS/$FILEHS,${FILEHS}Old/g" bench-graph.cabal
sed -ri "s/$NAME(.*)/old, $NAME\1/g" bench-graph.cabal

cp bench/Alga/Graph.hs bench/Alga/GraphOld.hs

sed -i "s/Alga.Graph/Alga.GraphOld/g" bench/Alga/GraphOld.hs
sed -i "s/Algebra.Graph/${FILEHS}Old/g" bench/Alga/GraphOld.hs
sed -i "s/Algebra.Graph/${FILEHS}/g" bench/Alga/Graph.hs

if [ "$5" = "True" ]
then
  for n in "bench/Alga/Graph.hs" "bench/Alga/GraphOld.hs"
  do
    sed -i "s/import BenchGraph.Types/import BenchGraph.Types\nimport qualified Data.List.NonEmpty as L/" $n
    sed -i 's/Graph Int/NonEmptyGraph Int/g' $n
    sed -i 's/mk = edges/mk = edges1 . L.fromList/' $n
    sed -i 's/clique/clique1 $ L.fromList/g' $n
    sed -i 's/, S.isEmpty isEmpty//g' $n
    sed -i 's/ vertexList/ vertexList1/g' $n
    sed -i  's/ removeVertex/ removeVertex1/g' $n
  done
fi

sed -i "s/import qualified Alga.Graph/import qualified Alga.Graph\nimport qualified Alga.GraphOld/g" bench/ListS.hs
sed -i "s/(\(\"Alga\", map Shadow Alga.Graph.functions \))/\(\1\),\(\"AlgaOld\", map Shadow Alga.GraphOld.functions \)/g" bench/ListS.hs

sed -i "s/import qualified Alga.Graph/import qualified Alga.Graph\nimport qualified Alga.GraphOld/g" bench/Time.hs
sed -i "s/(\(\"Alga\", benchmarkCreation dontBenchLittleOnes gr Alga.Graph.mk \))/\(\1\),\(\"AlgaOld\", benchmarkCreation dontBenchLittleOnes gr Alga.GraphOld.mk \)/g" bench/Time.hs

if [ "$1" = "Stack" ]
then
  stack build "bench-graph:bench:time" --no-run-benchmarks --flag "bench-graph:-reallife" --flag "bench-graph:-datasize" --flag "bench-graph:-space" --flag "bench-graph:-fgl"  --flag "bench-graph:-hashgraph" --flag "bench-graph:-chart"
else
  cabal -f -Datasize -f -Space -f -Fgl -f -HashGraph -f -RealLife -f -Chart new-build time --enable-benchmarks
fi

STR=""

ARGS=$(echo "$@" | cut -d' ' -f6-)

for var in $ARGS
do
	STR="$STR --only $var"
done

CMDARGS="run -g (\"Mesh\",3) -g (\"Clique\",3) -g (\"Circuit\",3) -i -d $3 -l Alga -l AlgaOld $STR"

echo $CMDARGS

if [ "$1" = "Stack" ]
then
  .stack-work/dist/*/*/build/time/time $CMDARGS 0>&0
else
  ./dist-newstyle/build/x86_64-linux/*/$BGVERSION/build/time/time $CMDARGS 0>&0
fi
popd
