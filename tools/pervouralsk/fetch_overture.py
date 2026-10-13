"""Скачивает открытые данные (Overture Maps, источник — OpenStreetMap) по центру Первоуральска.
Пример: python3 fetch_overture.py buildings building id,geometry,height,num_floors,class,subtype,names,bbox
"""
import os, sys, pyarrow.dataset as ds, pyarrow.fs as pfs, pyarrow.compute as pc, pyarrow.parquet as pq
REL = "release/2026-09-23.1"
W, S_, E, N = 59.905, 56.890, 59.985, 56.928
fs = pfs.S3FileSystem(anonymous=True, region="us-west-2", proxy_options="http://127.0.0.1:35801", tls_ca_file_path="/root/.ccr/ca-bundle.crt")
theme, typ = sys.argv[1], sys.argv[2]
path = f"overturemaps-us-west-2/{REL}/theme={theme}/type={typ}/"
d = ds.dataset(path, filesystem=fs, format="parquet")
b = ds.field("bbox")
flt = (ds.field("bbox", "xmin") < E) & (ds.field("bbox", "xmax") > W) & (ds.field("bbox", "ymin") < N) & (ds.field("bbox", "ymax") > S_)
cols = [c for c in sys.argv[3].split(",")]
t = d.to_table(filter=flt, columns=cols)
pq.write_table(t, os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", f"{theme}_{typ}.parquet"))
print(theme, typ, t.num_rows)
