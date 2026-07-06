import pandas as pd
import math
import glob
from datetime import datetime
import numpy as np
from plotly.subplots import make_subplots
import plotly.graph_objects as go

def convert_time(timestamp):
    time_string = timestamp.split('.')[0]
    if 'Z' in time_string:
        time_string = time_string[:-1]
    d = datetime.strptime(time_string,'%Y-%m-%dT%H:%M:%S')
    return ((d-datetime(1970,1,1)).total_seconds())

all_data = pd.DataFrame()
for file in glob.glob('/home/lb3416/Results/LoRaGatewayParsedLogs/dataset/*.csv'):
    data = pd.read_csv(file)
    data = data[['time','device_address','gateway','frequency','spreading_factor','rssi','snr','size','mtype']]
    all_data = all_data.append(data,ignore_index=True)
all_data['time'] = pd.to_datetime(all_data['time'])
all_data.sort_values(by='time',inplace=True)
all_data.reset_index(drop=True,inplace=True)


# ### Total messages
# The graph below shows the total messages received per day at a gateway. The data includes messages with a valid and invalid CRC. Number of messages with a valid CRC are lower than what is shown below.

fig = make_subplots()
for gw in all_data.gateway.unique():
    parsed = (all_data.where(all_data["gateway"] == gw).groupby(pd.Grouper(key='time', freq='1d')).count()).unstack()
    fig.add_trace(go.Scatter(y=parsed['device_address'],name=gw))
fig.update_layout(
    title="Total messages per day",
    xaxis_title="Number of days",
    yaxis_title="Number of messages",
    )
fig.update_yaxes
fig.show()


# ### PMF for number of messages per node
# The results below show the number of messages for (80)% of the nodes.

PERCENTILE = 20.0
parsed = all_data[all_data["device_address"] != '-1']
parsed = parsed[['time','device_address','gateway']].groupby(['gateway','device_address']).count()
fig = go.Figure()
for gw in all_data.gateway.unique():
    p1 = parsed.loc[gw,slice(None)]['time']
    upper_limit = np.percentile(np.unique(p1.values),100-(PERCENTILE/2))
    lower_limit = np.percentile(np.unique(p1.values),(PERCENTILE/2))
    fig.add_trace(go.Histogram(x=p1.values[(p1.values > lower_limit) & (p1.values < upper_limit)],name=str(gw)))

fig.update_layout(
    title="Distribution of {}% nodes".format(100-PERCENTILE),
    xaxis_title="Number of messages",
    yaxis_title="Number of nodes",
    )
fig.show()


# ### Distribution of message types over gateways
# The graph below shows the percentage of messages with a given message type at every gateway

fig = go.Figure()
local = all_data[all_data['mtype'] != -1]
total = local.groupby('gateway').count()['time']
parsed = (local.groupby(['gateway','mtype']).count()['time'])/total
for mtype in local.mtype.sort_values().unique():
    p1 = parsed.loc[slice(None),mtype]
    fig.add_trace(go.Bar(x=p1.index,y=p1.values,name=str(mtype)))
fig.update_layout(barmode='stack')
fig.show()


# ### Distribution of frequency over gateways
# The graph below shows the percentage of messages that transmitted with the given frequency at every gateway

fig = go.Figure()
local = all_data[all_data['frequency'] != -1]
total = local.groupby('gateway').count()['time']
parsed = (local.groupby(['gateway','frequency']).count()['time'])/total
for frequency in local.frequency.unique():
    p1 = parsed.loc[slice(None),frequency]
    fig.add_trace(go.Bar(x=p1.index,y=p1.values,name=str(frequency)))
fig.update_layout(barmode='stack')
fig.show()


# ### Distribution of Spreading factors over gateways
# The graph below shows the percentage of messages transmitted with a spreading factor at every gateway

fig = go.Figure()
local = all_data[all_data['spreading_factor'] != -1]
total = local.groupby('gateway').count()['time']
parsed = (local.groupby(['gateway','spreading_factor']).count()['time'])/total
for spreading_factor in local.spreading_factor.dropna().sort_values().unique():
    p1 = parsed.loc[slice(None),spreading_factor]
    fig.add_trace(go.Bar(x=p1.index,y=p1.values,name=str(spreading_factor)))
fig.update_layout(barmode='stack',legend_title_text='Spreading Factor')
fig.show()


# ### PMF of RSSI at every gateway
# The graph below shows the number of messages received with a particular RSSI at every gateway

parsed = all_data[['time','rssi','gateway']].groupby(['gateway','rssi']).count()
fig = go.Figure()
for gw in all_data.gateway.unique():
    p1 = parsed.loc[gw,slice(None)]['time']
    fig.add_trace(go.Scatter(x=p1.index,y=p1.values,name=str(gw)))

fig.update_layout(
    title="Number of messages with a given RSSI value at a gateway",
    xaxis_title="RSSI values",
    yaxis_title="Number of messages",
    )
fig.show()


# ### PMF of SNR at every gateway
# The graph below shows the number of messages received with a particular SNR at every gateway

parsed = all_data[['time','snr','gateway']].groupby(['gateway','snr']).count()
fig = go.Figure()
for gw in all_data.gateway.unique():
    p1 = parsed.loc[gw,slice(None)]['time']
    fig.add_trace(go.Scatter(x=p1.index,y=p1.values,name=str(gw)))

fig.update_layout(
    title="Number of messages with a given SNR value at a gateway",
    xaxis_title="SNR values",
    yaxis_title="Number of messages",
    )
fig.show()

parsed = all_data[['rssi','snr']]
parsed = parsed[(parsed['rssi'] < -150) & (parsed['rssi'] > -70) & (parsed['snr'] < 10) & (parsed['snr'] > -15)]
go.Figure(go.Histogram2dContour(y=parsed['rssi'],x=parsed['snr']))

