import os
import uuid
import json
import pandas as pd


input_path = os.path.join(os.getcwd(), "..", "results", "query_results")

query_stats_path = os.path.join(input_path, "query_stats")
ingestion_stats_path = os.path.join(input_path, "ingestion_stats")

output_path = os.path.join(input_path, "query_evaluation")
output_file = os.path.join(output_path, "aeong_statistics.csv")

csv_header = (
    "test_id,model,datasetSize,threads,queryName,queryType,elapsedTime,numEntities,numMachines"
)

indexes = {"queryName": 0, "datasetSize": 1, "threads": 2}


def load_first_json(path):
    with open(path, "r", encoding="utf-8") as f:
        s = f.read()

    dec = json.JSONDecoder()
    i = 0
    while i < len(s) and s[i].isspace():
        i += 1

    obj, end = dec.raw_decode(s, i)
    return obj


def create_csv(filename, header):
    if os.path.exists(filename):
        df = pd.read_csv(filename)
        print("Statistics file already exists")
    else:
        df = pd.DataFrame(columns=header.split(","))
        df.to_csv(filename, index=False)
        print("Created new statistics file...")
    return df


myUUID = uuid.uuid4()

# Create output directory if it doesn't exist
os.makedirs(output_path, exist_ok=True)

statistics_df = create_csv(output_file, csv_header)

for file in os.listdir(query_stats_path):

    query_name = file.split("_")[indexes["queryName"]]
    dataset_size = file.split("_")[indexes["datasetSize"]].replace("sz", "")
    threads = file.split("_")[indexes["threads"]].replace("wrk", "")

    with open(os.path.join(query_stats_path, file), "r", encoding="utf-8") as f:
        try:
            # prendo solo la prima riga non vuota
            first_line = ""
            for line in f:
                if line.strip():
                    first_line = line
                    break

            if first_line:
                data = json.loads(first_line)
                duration = data["duration"]
                statistics_df = pd.concat(
                    [
                        statistics_df,
                        pd.DataFrame(
                            [
                                {
                                    "test_id": str(myUUID),
                                    "model": "aeong",
                                    "datasetSize": dataset_size,
                                    "threads": threads,
                                    "queryName": query_name,
                                    "queryType": "edgesDirection",
                                    "elapsedTime": int(max(float(duration) * 1000, 1)),
                                    "numEntities": -1,
                                    "numMachines": 1,
                                }
                            ]
                        ),
                    ],
                    ignore_index=True,
                )
        except json.JSONDecodeError as e:
            print(f"Skipping file {file} due to JSON decode error: {e}")
            continue

# Save the updated DataFrame to CSV
statistics_df.to_csv(output_file, index=False)
