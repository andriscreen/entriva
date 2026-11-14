<script setup lang="ts">
import { MessageSquareText, RefreshCw, TicketCheck, Wifi, WifiOff } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Progress } from '@/components/ui/progress'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

definePageMeta({ layout: 'dashboard' })

const tickets = [
  { id: 'INC-2048', issue: 'Expired WiFi voucher', location: 'Gate 2', priority: 'High', age: '8 min' },
  { id: 'INC-2047', issue: 'Visitor tablet offline', location: 'Reception', priority: 'Medium', age: '21 min' },
  { id: 'INC-2044', issue: 'OpenWA QR refresh request', location: 'Gate 1', priority: 'Low', age: '43 min' },
]
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div><p class="text-sm text-muted-foreground">Infrastructure and access</p><h1 class="text-3xl font-semibold tracking-tight">IT support center</h1></div>
      <Button variant="outline"><RefreshCw class="size-4" /> Refresh services</Button>
    </div>

    <section class="grid gap-4 md:grid-cols-3" aria-label="IT support status">
      <Card>
        <CardHeader class="flex-row items-start justify-between space-y-0"><div><CardDescription>OpenWA gateway</CardDescription><CardTitle class="mt-2 text-xl">Connected</CardTitle></div><MessageSquareText class="size-5 text-emerald-500" /></CardHeader>
        <CardContent class="pt-0"><p class="text-xs text-muted-foreground">4 gate sessions active</p></CardContent>
      </Card>
      <Card>
        <CardHeader class="flex-row items-start justify-between space-y-0"><div><CardDescription>WiFi voucher pool</CardDescription><CardTitle class="mt-2 text-3xl">812</CardTitle></div><Wifi class="size-5 text-primary" /></CardHeader>
        <CardContent class="pt-0"><Progress :model-value="81" /><p class="mt-2 text-xs text-muted-foreground">81% of provisioned capacity available</p></CardContent>
      </Card>
      <Card>
        <CardHeader class="flex-row items-start justify-between space-y-0"><div><CardDescription>Open incidents</CardDescription><CardTitle class="mt-2 text-3xl">7</CardTitle></div><TicketCheck class="size-5 text-amber-500" /></CardHeader>
        <CardContent class="pt-0"><p class="text-xs text-amber-600">2 tickets approaching SLA</p></CardContent>
      </Card>
    </section>

    <Card>
      <CardHeader><CardTitle>Support tickets</CardTitle><CardDescription>Prioritize access and facility connectivity incidents.</CardDescription></CardHeader>
      <CardContent>
        <Table>
          <TableHeader><TableRow><TableHead>Ticket</TableHead><TableHead>Issue</TableHead><TableHead>Location</TableHead><TableHead>Age</TableHead><TableHead>Priority</TableHead><TableHead /></TableRow></TableHeader>
          <TableBody>
            <TableRow v-for="ticket in tickets" :key="ticket.id">
              <TableCell class="font-mono text-xs">{{ ticket.id }}</TableCell><TableCell class="font-medium">{{ ticket.issue }}</TableCell>
              <TableCell>{{ ticket.location }}</TableCell><TableCell>{{ ticket.age }}</TableCell>
              <TableCell><Badge :variant="ticket.priority === 'High' ? 'destructive' : 'outline'">{{ ticket.priority }}</Badge></TableCell>
              <TableCell><Button variant="ghost" size="sm">Open</Button></TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </CardContent>
    </Card>

    <Card>
      <CardHeader><CardTitle class="flex items-center gap-2"><WifiOff class="size-4" /> Service health</CardTitle><CardDescription>Current status of connected operational services.</CardDescription></CardHeader>
      <CardContent class="grid gap-3 sm:grid-cols-3">
        <div v-for="service in [{ name: 'OpenWA', state: 'Operational' }, { name: 'RADIUS', state: 'Operational' }, { name: 'Gate scanner API', state: 'Degraded' }]" :key="service.name" class="flex items-center justify-between rounded-lg border p-3">
          <span class="text-sm font-medium">{{ service.name }}</span><Badge :variant="service.state === 'Operational' ? 'secondary' : 'outline'">{{ service.state }}</Badge>
        </div>
      </CardContent>
    </Card>
  </div>
</template>
