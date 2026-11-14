<script setup lang="ts">
import { ArrowRight, CheckCircle2, Clock3, Dock, Truck } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

definePageMeta({ layout: 'dashboard' })

const queue = [
  { plate: 'B 9214 KXY', vendor: 'PT Sumber Pangan', load: 'Raw materials', arrived: '08:42', status: 'Waiting' },
  { plate: 'F 8821 QP', vendor: 'CV Trans Utama', load: 'Packaging', arrived: '08:35', status: 'Approved' },
  { plate: 'B 7610 JQ', vendor: 'PT Mitra Logistik', load: 'Finished goods', arrived: '08:18', status: 'Waiting' },
]

const docks = [
  { name: 'Dock 01', shipment: 'PO-24018', status: 'In use' },
  { name: 'Dock 02', shipment: 'Available', status: 'Available' },
  { name: 'Dock 03', shipment: 'PO-24021', status: 'In use' },
]
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div>
        <p class="text-sm text-muted-foreground">Logistics operations</p>
        <h1 class="text-3xl font-semibold tracking-tight">Driver approval queue</h1>
      </div>
      <Button><Truck class="size-4" /> Register arrival</Button>
    </div>

    <section class="grid gap-4 md:grid-cols-3" aria-label="Logistics metrics">
      <Card>
        <CardHeader><CardDescription>Vehicles waiting</CardDescription><CardTitle class="text-3xl">18</CardTitle></CardHeader>
        <CardContent class="pt-0"><p class="flex items-center gap-2 text-xs text-amber-500"><Clock3 class="size-3.5" /> 6 waiting over 20 minutes</p></CardContent>
      </Card>
      <Card>
        <CardHeader><CardDescription>Dock occupancy</CardDescription><CardTitle class="text-3xl">68%</CardTitle></CardHeader>
        <CardContent class="pt-0"><p class="text-xs text-muted-foreground">2 of 6 docks are available</p></CardContent>
      </Card>
      <Card>
        <CardHeader><CardDescription>Approved today</CardDescription><CardTitle class="text-3xl">31</CardTitle></CardHeader>
        <CardContent class="pt-0"><p class="flex items-center gap-2 text-xs text-emerald-600"><CheckCircle2 class="size-3.5" /> Normal operation</p></CardContent>
      </Card>
    </section>

    <section class="grid gap-6 xl:grid-cols-[1.4fr_0.8fr]">
      <Card>
        <CardHeader>
          <CardTitle>Waiting drivers</CardTitle>
          <CardDescription>Review vehicle arrivals and approve gate access.</CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader><TableRow><TableHead>Vehicle</TableHead><TableHead>Vendor / load</TableHead><TableHead>Arrival</TableHead><TableHead>Status</TableHead><TableHead /></TableRow></TableHeader>
            <TableBody>
              <TableRow v-for="driver in queue" :key="driver.plate">
                <TableCell class="font-medium">{{ driver.plate }}</TableCell>
                <TableCell><span class="block">{{ driver.vendor }}</span><span class="text-xs text-muted-foreground">{{ driver.load }}</span></TableCell>
                <TableCell>{{ driver.arrived }}</TableCell>
                <TableCell><Badge :variant="driver.status === 'Approved' ? 'secondary' : 'outline'">{{ driver.status }}</Badge></TableCell>
                <TableCell><Button variant="ghost" size="sm" :aria-label="`Review ${driver.plate}`"><ArrowRight class="size-4" /></Button></TableCell>
              </TableRow>
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle class="flex items-center gap-2"><Dock class="size-4" /> Dock assignment</CardTitle>
          <CardDescription>Current loading bay availability.</CardDescription>
        </CardHeader>
        <CardContent class="space-y-3">
          <Card v-for="dock in docks" :key="dock.name" size="sm" class="bg-muted/30">
            <CardContent class="flex items-center justify-between p-3">
              <div><p class="font-medium">{{ dock.name }}</p><p class="text-xs text-muted-foreground">{{ dock.shipment }}</p></div>
              <Badge :variant="dock.status === 'Available' ? 'secondary' : 'outline'">{{ dock.status }}</Badge>
            </CardContent>
          </Card>
        </CardContent>
      </Card>
    </section>
  </div>
</template>
