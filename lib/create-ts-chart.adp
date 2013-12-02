<script>

<if @no_records_found_msg@ eq "">

Ext.require('Ext.chart.*');
Ext.require(['Ext.layout.container.Fit', 'Ext.window.MessageBox']);
Ext.onReady(function () {
     window.store1 = Ext.create('Ext.data.JsonStore', {
        fields: [@json_data_fields;noquote@],
      data : [@json_data;noquote@]
    });
    var donut = false,
        chart = Ext.create('Ext.chart.Chart', {
	       width: 600,
        	  height: 450,
	       renderTo: 'chart_pie',
            xtype: 'chart',
            animate: true,
            store: store1,
            shadow: true,
            legend: {
                position: 'right'
            },
            insetPadding: 60,
            theme: 'Base:gradients',
            series: [{
                type: 'pie',
                field: 'data1',
                showInLegend: true,
                donut: donut,
                tips: {
                  trackMouse: true,
                  width: 140,
                  height: 28,
                  renderer: function(storeItem, item) {
                    //calculate percentage.
                    var total = 0;
                    store1.each(function(rec) {
                        total += rec.get('data1');
                    });
                    this.setTitle(storeItem.get('name') + ': ' + Math.round(storeItem.get('data1') / total * 100) + '%');
                  }
                },
                highlight: {
                  segment: {
                    margin: 20
                  }
                },
                label: {
                    field: 'name',
                    display: 'rotate',
                    contrast: true,
                    font: '10px Arial'
                }
            }]
        });
});

</if>
<else>

Ext.onReady(function () {
	 Ext.fly('chart_pie').update('@no_records_found_msg@');
});

</else>

</script>
