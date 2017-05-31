import networkx as nx
import nump as np

conn=np.load(seed_directory + "/conn.mat") 
G = nx.from_numpy_matrix(conn)
for n, name in zip(G.nodes_iter(), processed_seed_list):
    G.node[n]['name'] = name

G = nx.MultiDiGraph()
for i, name in enumerate(processed_seed_list):
    G.add_node(i, attr_dict={'name': name})
for i, row in enumerate(conn):
    for j, val in enumerate(row):
        if i != j:
            if val > 1:
                G.add_edge(i, j, weight=val)

name_to_deg = {G.node[i]['name']: val for i, val in G.degree().iteritems()}
sorted(name_to_deg, key=lambda x: name_to_deg[x], reverse=True )
