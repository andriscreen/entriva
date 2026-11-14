<script setup lang="ts">
import { BedDouble, CalendarCheck, UserRoundCheck } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

definePageMeta({ layout: 'dashboard' })

const visitors = [
  { name: 'Rina Kusuma', host: 'Dewi Anggraini', company: 'PT Karya Mandiri', time: '09:15', status: 'Awaiting approval' },
  { name: 'Andi Pratama', host: 'Budi Santoso', company: 'Mitra Teknik', time: '09:30', status: 'Approved' },
  { name: 'Nadia Putri', host: 'Rizky Hidayat', company: 'PT Sejahtera', time: '10:00', status: 'Checked in' },
]

const rooms = [
  { name: 'Mess A', occupied: '18 / 24', status: 'Available' },
  { name: 'Mess B', occupied: '24 / 24', status: 'Full' },
  { name: 'Mess C', occupied: '11 / 20', status: 'Available' },
]
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div><p class="text-sm text-muted-foreground">Facility services</p><h1 class="text-3xl font-semibold tracking-tight">Visitor management</h1></div>
      <Button><UserRoundCheck class="size-4" /> Register visitor</Button>
    </div>

    <section class="grid gap-4 md:grid-cols-3" aria-label="Facility metrics">
      <Card><CardHeader><CardDescription>Guest check-ins today</CardDescription><CardTitle class="text-3xl">76</CardTitle></CardHeader><CardContent class="pt-0"><p class="text-xs text-muted-foreground">Across all plant gates</p></CardContent></Card>
      <Card><CardHeader><CardDescription>Pending approvals</CardDescription><CardTitle class="text-3xl">11</CardTitle></CardHeader><CardContent class="pt-0"><p class="text-xs text-amber-600">3 arrivals within the hour</p></CardContent></Card>
      <Card><CardHeader><CardDescription>Mess room reservations</CardDescription><CardTitle class="text-3xl">2</CardTitle></CardHeader><CardContent class="pt-0"><p class="text-xs text-muted-foreground">Next arrival at 11:30</p></CardContent></Card>
    </section>

    <section class="grid gap-6 xl:grid-cols-[1.25fr_0.75fr]">
      <Card>
        <CardHeader><CardTitle>Today’s visitors</CardTitle><CardDescription>Review guest invitations and gate check-in status.</CardDescription></CardHeader>
        <CardContent>
          <Table>
            <TableHeader><TableRow><TableHead>Visitor</TableHead><TableHead>Host</TableHead><TableHead>Arrival</TableHead><TableHead>Status</TableHead><TableHead /></TableRow></TableHeader>
            <TableBody>
              <TableRow v-for="visitor in visitors" :key="visitor.name">
                <TableCell><span class="block font-medium">{{ visitor.name }}</span><span class="text-xs text-muted-foreground">{{ visitor.company }}</span></TableCell>
                <TableCell>{{ visitor.host }}</TableCell><TableCell>{{ visitor.time }}</TableCell>
                <TableCell><Badge :variant="visitor.status === 'Approved' || visitor.status === 'Checked in' ? 'secondary' : 'outline'">{{ visitor.status }}</Badge></TableCell>
                <TableCell><Button v-if="visitor.status === 'Awaiting approval'" size="sm">Review</Button></TableCell>
              </TableRow>
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <Card>
        <CardHeader><CardTitle class="flex items-center gap-2"><BedDouble class="size-4" /> Mess room allocation</CardTitle><CardDescription>Occupancy and room availability.</CardDescription></CardHeader>
        <CardContent class="space-y-3">
          <Card v-for="room in rooms" :key="room.name" size="sm" class="bg-muted/30">
            <CardContent class="flex items-center justify-between p-3">
              <div><p class="font-medium">{{ room.name }}</p><p class="text-xs text-muted-foreground">{{ room.occupied }} beds used</p></div>
              <Badge :variant="room.status === 'Full' ? 'outline' : 'secondary'">{{ room.status }}</Badge>
            </CardContent>
          </Card>
          <Button variant="outline" class="w-full"><CalendarCheck class="size-4" /> Manage reservations</Button>
        </CardContent>
      </Card>
    </section>
  </div>
</template>
