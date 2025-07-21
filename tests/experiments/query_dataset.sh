
echo "=============AeonG graph operation latency & spance==========="
echo "graph_op_latency:$graph_op_latency"
echo "storage_consumption:$storage_consumption"

aeong_binary="--aeong-binary ../../build/memgraph"
client_binary="--client-binary ../../build/tests/mgbench/client"
number_workers="--num-workers 1"
database_directory="--data-directory $prefix_path/database/aeong"
index_path="--index-cypher-path ../datasets/T-mgBench/cypher_index.cypher"
temporal_query_path=$prefix_path"temporal_query/small"
python_script="../scripts/evaluate_temporal_q.py"
temporal_q1="--temporal-query-cypher-path $temporal_query_path/cypher_Q1.txt"
temporal_q2="--temporal-query-cypher-path $temporal_query_path/cypher_Q2.txt"
temporal_q3="--temporal-query-cypher-path $temporal_query_path/cypher_Q3.txt"
temporal_q4="--temporal-query-cypher-path $temporal_query_path/cypher_Q4.txt"
temporal_q4_long="--temporal-query-cypher-path $temporal_query_path/cypher_Q4_long.txt"
temporal_q5="--temporal-query-cypher-path $temporal_query_path/cypher_Q5.txt"
temporal_q6="--temporal-query-cypher-path $temporal_query_path/cypher_Q6.txt"

output_q1="--output /q1.json"
output_q2="--output /q2.json"
output_q3="--output /q3.json"
output_q4="--output /q4.json"
output_q4_long="--output /q4_long.json"
output_q5="--output /q5.json"
output_q6="--output /q6.json"

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
echo "AeonG q4 mix_long"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q4_long $output_q4_long
echo "AeonG q5 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q5 $output_q5
echo "AeonG q6 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q6 $output_q6