<script setup lang="ts">
import { ArrowRight, CalendarDays, Clock3, Plus, UserRoundPlus } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

definePageMeta({ layout: 'dashboard' })

const guests = [
  { name: 'Rina Kusuma', purpose: 'Project review', date: 'Today, 10:00', status: 'Approved' },
  { name: 'Fajar Nugraha', purpose: 'Vendor meeting', date: 'Today, 13:30', status: 'Awaiting approval' },
  { name: 'Maya Lestari', purpose: 'Site visit', date: 'Tomorrow, 09:00', status: 'Approved' },
]
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div><p class="text-sm text-muted-foreground">Host workspace</p><h1 class="text-3xl font-semibold tracking-tight">Guest invitations</h1></div>
      <Button><Plus class="size-4" /> Create invitation</Button>
    </div>

    <section class="grid gap-4 md:grid-cols-3" aria-label="Invitation summary">
      <Card><CardHeader><CardDescription>Invitations this month</CardDescription><CardTitle class="text-3xl">36</CardTitle></CardHeader><CardContent class="pt-0"><p class="text-xs text-muted-foreground">5 sent this week</p></CardContent></Card>
      <Card><CardHeader><CardDescription>Guests arriving</CardDescription><CardTitle class="text-3xl">2</CardTitle></CardHeader><CardContent class="pt-0"><p class="text-xs text-muted-foreground">Next arrival at 10:00</p></CardContent></Card>
      <Card><CardHeader><CardDescription>Awaiting approval</CardDescription><CardTitle class="text-3xl">1</CardTitle></CardHeader><CardContent class="pt-0"><p class="text-xs text-amber-600">Facility team is reviewing</p></CardContent></Card>
    </section>

    <Card>
      <CardHeader class="flex-row items-center justify-between space-y-0">
        <div><CardTitle>Your guest schedule</CardTitle><CardDescription class="mt-1">Upcoming invitations and their gate access status.</CardDescription></div>
        <Button variant="outline"><CalendarDays class="size-4" /> Full schedule</Button>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader><TableRow><TableHead>Guest</TableHead><TableHead>Visit purpose</TableHead><TableHead>Visit time</TableHead><TableHead>Status</TableHead><TableHead /></TableRow></TableHeader>
          <TableBody>
            <TableRow v-for="guest in guests" :key="guest.name">
              <TableCell class="font-medium">{{ guest.name }}</TableCell><TableCell>{{ guest.purpose }}</TableCell>
              <TableCell><span class="flex items-center gap-2"><Clock3 class="size-3.5 text-muted-foreground" />{{ guest.date }}</span></TableCell>
              <TableCell><Badge :variant="guest.status === 'Approved' ? 'secondary' : 'outline'">{{ guest.status }}</Badge></TableCell>
              <TableCell><Button variant="ghost" size="icon" :aria-label="`View ${guest.name} invitation`"><ArrowRight class="size-4" /></Button></TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </CardContent>
    </Card>

    <Card class="border-dashed">
      <CardContent class="flex flex-wrap items-center justify-between gap-4 p-5">
        <div class="flex items-center gap-3">
          <span class="flex size-10 items-center justify-center rounded-xl bg-primary/10 text-primary"><UserRoundPlus class="size-5" /></span>
          <div><p class="font-medium">Expecting a new guest?</p><p class="text-sm text-muted-foreground">Send an invitation before they arrive at the gate.</p></div>
        </div>
        <Button variant="outline"><Plus class="size-4" /> New invitation</Button>
      </CardContent>
    </Card>
  </div>
</template>
