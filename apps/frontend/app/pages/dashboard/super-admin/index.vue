<script setup lang="ts">
import {
  ArrowUpRight,
  Building2,
  ClipboardCheck,
  Settings2,
  Users,
} from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'

definePageMeta({
  layout: 'dashboard',
  path: '/dashboard/super-admin',
})

const metrics = [
  { label: 'Active plants', value: '4', trend: 'All plants online', icon: Building2 },
  { label: 'Visitors today', value: '186', trend: '+24 from yesterday', icon: Users },
  { label: 'Pending reviews', value: '18', trend: '6 require attention', icon: ClipboardCheck },
]

const plants = [
  { name: 'Jatake 1', code: 'JT-01', guests: 58, status: 'Operational' },
  { name: 'Jatake 2', code: 'JT-02', guests: 43, status: 'Operational' },
  { name: 'Jatake 3', code: 'JT-03', guests: 51, status: 'Operational' },
  { name: 'Jatake 6', code: 'JT-06', guests: 34, status: 'Maintenance' },
]
</script>

<template>
  <div class="space-y-6">
    <Card>
      <CardContent class="flex flex-wrap items-center justify-between gap-5 bg-gradient-to-r from-primary/10 via-card to-card p-6">
        <div>
          <p class="text-xs uppercase tracking-[0.2em] text-primary">System administration</p>
          <h1 class="mt-2 text-3xl font-semibold tracking-tight">Super Admin System</h1>
          <p class="mt-2 text-sm text-muted-foreground">
            Plant-wide governance, operational health, and system controls.
          </p>
        </div>
        <Button>
          <Settings2 class="size-4" />
          System settings
        </Button>
      </CardContent>
    </Card>

    <section class="grid gap-4 md:grid-cols-3" aria-label="System metrics">
      <Card v-for="metric in metrics" :key="metric.label">
        <CardHeader class="flex-row items-start justify-between space-y-0">
          <div class="space-y-1">
            <CardDescription>{{ metric.label }}</CardDescription>
            <CardTitle class="text-3xl">{{ metric.value }}</CardTitle>
          </div>
          <span class="flex size-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
            <component :is="metric.icon" class="size-5" />
          </span>
        </CardHeader>
        <CardContent class="pt-0">
          <p class="text-xs text-muted-foreground">{{ metric.trend }}</p>
        </CardContent>
      </Card>
    </section>

    <Card>
      <CardHeader class="flex-row items-center justify-between space-y-0">
        <div>
          <CardTitle>Plant status</CardTitle>
          <CardDescription class="mt-1">Current operational health across Jatake facilities.</CardDescription>
        </div>
        <Button variant="outline" size="sm">
          View all
          <ArrowUpRight class="size-4" />
        </Button>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Plant</TableHead>
              <TableHead>Plant code</TableHead>
              <TableHead>Visitors today</TableHead>
              <TableHead class="text-right">Status</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            <TableRow v-for="plant in plants" :key="plant.code">
              <TableCell class="font-medium">{{ plant.name }}</TableCell>
              <TableCell class="text-muted-foreground">{{ plant.code }}</TableCell>
              <TableCell>{{ plant.guests }}</TableCell>
              <TableCell class="text-right">
                <Badge :variant="plant.status === 'Operational' ? 'secondary' : 'outline'">
                  {{ plant.status }}
                </Badge>
              </TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  </div>
</template>
