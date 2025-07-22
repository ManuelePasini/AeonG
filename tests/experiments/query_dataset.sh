
echo "=============AeonG graph operation latency & spance==========="
echo "graph_op_latency:$graph_op_latency"
echo "storage_consumption:$storage_consumption"

aeong_binary="--aeong-binary ../../build/memgraph"
client_binary="--client-binary ../../build/tests/mgbench/client"
number_workers="--num-workers 1"
prefix_path="../results/"
database_directory="--data-directory $prefix_path/database/aeong"
index_path="--index-cypher-path ../datasets/T-mgBench/cypher_index.cypher"
temporal_query_path=$prefix_path"temporal_query/small"
python_script="../scripts/evaluate_temporal_q.py"

temporal_q1="--temporal-query-cypher-path $temporal_query_path/EnvironmentCoverage.txt"
temporal_q2="--temporal-query-cypher-path $temporal_query_path/EnvironmentAggregate.txt"
temporal_q3="--temporal-query-cypher-path $temporal_query_path/MaintenanceOwners.txt"
temporal_q4="--temporal-query-cypher-path $temporal_query_path/EnvironmentOutlier.txt"
temporal_q5="--temporal-query-cypher-path $temporal_query_path/AgentOutlier.txt"
temporal_q6="--temporal-query-cypher-path $temporal_query_path/AgentHistory.txt"

output_q1="--output /EnvironmentCoverage.json"
output_q2="--output /EnvironmentAggregate.json"
output_q3="--output /MaintenanceOwners.json"
output_q4="--output /EnvironmentOutlier.json"
output_q5="--output /AgentOutlier.json"
output_q6="--output /AgentHistory.json"

SIZE="$1"
./update_queries.sh "$SIZE" "$temporal_query_path/"

echo "AeonG q1 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q1 $output_q1
echo "AeonG q2 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q2 $output_q2
echo "AeonG q3 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q3 $output_q3
echo "AeonG q4 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q4 $output_q4
echo "AeonG q5 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q5 $output_q5
echo "AeonG q6 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q6 $output_q6