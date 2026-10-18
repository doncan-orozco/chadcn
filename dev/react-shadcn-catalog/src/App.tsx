import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Checkbox } from '@/components/ui/checkbox'
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group'
import { Switch } from '@/components/ui/switch'
import { Textarea } from '@/components/ui/textarea'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Separator } from '@/components/ui/separator'
import { Skeleton } from '@/components/ui/skeleton'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger } from '@/components/ui/alert-dialog'
import { Table, TableBody, TableCell, TableFooter, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle, SheetTrigger } from '@/components/ui/sheet'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip'
import { MoreHorizontal as MoreHorizontalIcon } from 'lucide-react'

export default function App() {
  const [darkMode, setDarkMode] = useState(false)
  const [selectedCategory, setSelectedCategory] = useState('foundation')

  return (
    <div className={darkMode ? 'dark' : ''}>
      <div className="min-h-screen bg-background text-foreground">
        {/* Header */}
        <div className="border-b border-border bg-card">
          <div className="max-w-7xl mx-auto px-4 py-6">
            <div className="flex items-center justify-between">
              <div>
                <h1 className="text-3xl font-bold">shadcn/ui React Catalog</h1>
                <p className="text-muted-foreground mt-2">42 components • Zinc theme • OKLCH colors</p>
              </div>
              <div className="flex items-center gap-4">
                <Button 
                  variant="outline" 
                  size="sm"
                  onClick={() => setDarkMode(!darkMode)}
                >
                  {darkMode ? '☀️ Light' : '🌙 Dark'}
                </Button>
              </div>
            </div>
          </div>
        </div>

        {/* Navigation */}
        <div className="border-b border-border bg-card/50">
          <div className="max-w-7xl mx-auto px-4 py-4">
            <div className="flex gap-2 flex-wrap">
              {[
                { id: 'foundation', label: 'Foundation' },
                { id: 'forms', label: 'Forms' },
                { id: 'feedback', label: 'Feedback' },
                { id: 'overlays', label: 'Overlays' },
                { id: 'tables', label: 'Tables' },
                { id: 'complex', label: 'Complex' },
              ].map(cat => (
                <Button
                  key={cat.id}
                  variant={selectedCategory === cat.id ? 'default' : 'ghost'}
                  size="sm"
                  onClick={() => setSelectedCategory(cat.id)}
                >
                  {cat.label}
                </Button>
              ))}
            </div>
          </div>
        </div>

        {/* Main Content */}
        <div className="max-w-7xl mx-auto px-4 py-8">
          {/* Foundation Components */}
          {selectedCategory === 'foundation' && (
            <div className="space-y-8">
              <div>
                <h2 className="text-2xl font-bold mb-4">Foundation</h2>
                
                {/* Badge */}
                <Card className="mb-6">
                  <CardHeader>
                    <CardTitle>Badge</CardTitle>
                    <CardDescription>Label component for marking and categorizing</CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <div className="flex gap-2">
                      <Badge>Default</Badge>
                      <Badge variant="secondary">Secondary</Badge>
                      <Badge variant="destructive">Destructive</Badge>
                      <Badge variant="outline">Outline</Badge>
                    </div>
                  </CardContent>
                </Card>

                {/* Button */}
                <Card className="mb-6">
                  <CardHeader>
                    <CardTitle>Button</CardTitle>
                    <CardDescription>Interactive clickable element</CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <div className="flex flex-wrap gap-2">
                      <Button>Default</Button>
                      <Button variant="secondary">Secondary</Button>
                      <Button variant="destructive">Destructive</Button>
                      <Button variant="outline">Outline</Button>
                      <Button variant="ghost">Ghost</Button>
                      <Button disabled>Disabled</Button>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      <Button size="sm">Small</Button>
                      <Button size="default">Default</Button>
                      <Button size="lg">Large</Button>
                    </div>
                  </CardContent>
                </Card>

                {/* Separator */}
                <Card className="mb-6">
                  <CardHeader>
                    <CardTitle>Separator</CardTitle>
                    <CardDescription>Visual divider between sections</CardDescription>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-2">
                      <p>Section 1</p>
                      <Separator />
                      <p>Section 2</p>
                      <Separator className="my-4" />
                      <p>Section 3</p>
                    </div>
                  </CardContent>
                </Card>

                {/* Skeleton */}
                <Card>
                  <CardHeader>
                    <CardTitle>Skeleton</CardTitle>
                    <CardDescription>Loading placeholder</CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <Skeleton className="h-12 w-12 rounded-full" />
                    <Skeleton className="h-4 w-[250px]" />
                    <Skeleton className="h-4 w-[200px]" />
                  </CardContent>
                </Card>
              </div>
            </div>
          )}

          {/* Form Components */}
          {selectedCategory === 'forms' && (
            <div className="space-y-8">
              <h2 className="text-2xl font-bold">Forms & Inputs</h2>
              
              {/* Input */}
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>Input</CardTitle>
                  <CardDescription>Text input field</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div>
                    <Label htmlFor="input">Email</Label>
                    <Input id="input" placeholder="Enter your email" type="email" />
                  </div>
                  <div>
                    <Label htmlFor="input-disabled">Disabled</Label>
                    <Input id="input-disabled" placeholder="Disabled input" disabled />
                  </div>
                </CardContent>
              </Card>

              {/* Checkbox */}
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>Checkbox</CardTitle>
                  <CardDescription>Boolean input</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="flex items-center space-x-2">
                    <Checkbox id="terms" />
                    <Label htmlFor="terms">I agree to terms</Label>
                  </div>
                  <div className="flex items-center space-x-2">
                    <Checkbox id="checked" defaultChecked />
                    <Label htmlFor="checked">Already checked</Label>
                  </div>
                </CardContent>
              </Card>

              {/* Radio Group */}
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>Radio Group</CardTitle>
                  <CardDescription>Single selection from multiple options</CardDescription>
                </CardHeader>
                <CardContent>
                  <RadioGroup defaultValue="option-1">
                    <div className="flex items-center space-x-2">
                      <RadioGroupItem value="option-1" id="option-1" />
                      <Label htmlFor="option-1">Option 1</Label>
                    </div>
                    <div className="flex items-center space-x-2">
                      <RadioGroupItem value="option-2" id="option-2" />
                      <Label htmlFor="option-2">Option 2</Label>
                    </div>
                  </RadioGroup>
                </CardContent>
              </Card>

              {/* Switch */}
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>Switch</CardTitle>
                  <CardDescription>Toggle control</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="flex items-center space-x-2">
                    <Switch id="notifications" />
                    <Label htmlFor="notifications">Enable notifications</Label>
                  </div>
                  <div className="flex items-center space-x-2">
                    <Switch id="notifications-checked" defaultChecked />
                    <Label htmlFor="notifications-checked">Notifications enabled</Label>
                  </div>
                </CardContent>
              </Card>

              {/* Textarea */}
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>Textarea</CardTitle>
                  <CardDescription>Multi-line text input</CardDescription>
                </CardHeader>
                <CardContent>
                  <Textarea placeholder="Enter your message..." />
                </CardContent>
              </Card>

              {/* Select */}
              <Card>
                <CardHeader>
                  <CardTitle>Select</CardTitle>
                  <CardDescription>Dropdown selection</CardDescription>
                </CardHeader>
                <CardContent>
                  <Select>
                    <SelectTrigger>
                      <SelectValue placeholder="Select an option" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="apple">Apple</SelectItem>
                      <SelectItem value="banana">Banana</SelectItem>
                      <SelectItem value="orange">Orange</SelectItem>
                    </SelectContent>
                  </Select>
                </CardContent>
              </Card>
            </div>
          )}

          {/* Feedback Components */}
          {selectedCategory === 'feedback' && (
            <div className="space-y-8">
              <h2 className="text-2xl font-bold">Feedback & Status</h2>
              
              {/* Alert */}
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>Alert</CardTitle>
                  <CardDescription>Message with status indicator</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <Alert>
                    <AlertTitle>Info</AlertTitle>
                    <AlertDescription>This is an informational message.</AlertDescription>
                  </Alert>
                  <Alert variant="destructive">
                    <AlertTitle>Error</AlertTitle>
                    <AlertDescription>This is an error message.</AlertDescription>
                  </Alert>
                </CardContent>
              </Card>

              {/* Tabs */}
              <Card>
                <CardHeader>
                  <CardTitle>Tabs</CardTitle>
                  <CardDescription>Tabbed interface</CardDescription>
                </CardHeader>
                <CardContent>
                  <Tabs defaultValue="tab1">
                    <TabsList>
                      <TabsTrigger value="tab1">Tab 1</TabsTrigger>
                      <TabsTrigger value="tab2">Tab 2</TabsTrigger>
                      <TabsTrigger value="tab3">Tab 3</TabsTrigger>
                    </TabsList>
                    <TabsContent value="tab1">Content for Tab 1</TabsContent>
                    <TabsContent value="tab2">Content for Tab 2</TabsContent>
                    <TabsContent value="tab3">Content for Tab 3</TabsContent>
                  </Tabs>
                </CardContent>
              </Card>
            </div>
          )}

          {/* Overlay Components */}
          {selectedCategory === 'overlays' && (
            <div className="space-y-8">
              <h2 className="text-2xl font-bold">Overlays & Modals</h2>
              
              {/* Dialog */}
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>Dialog</CardTitle>
                  <CardDescription>Modal dialog window</CardDescription>
                </CardHeader>
                <CardContent>
                  <Dialog>
                    <DialogTrigger asChild>
                      <Button>Open Dialog</Button>
                    </DialogTrigger>
                    <DialogContent>
                      <DialogHeader>
                        <DialogTitle>Dialog Title</DialogTitle>
                        <DialogDescription>
                          This is a dialog description
                        </DialogDescription>
                      </DialogHeader>
                      <p>Dialog content goes here</p>
                    </DialogContent>
                  </Dialog>
                </CardContent>
              </Card>

              {/* Alert Dialog */}
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>Alert Dialog</CardTitle>
                  <CardDescription>Confirmation dialog</CardDescription>
                </CardHeader>
                <CardContent>
                  <AlertDialog>
                    <AlertDialogTrigger asChild>
                      <Button variant="destructive">Delete</Button>
                    </AlertDialogTrigger>
                    <AlertDialogContent>
                      <AlertDialogHeader>
                        <AlertDialogTitle>Are you sure?</AlertDialogTitle>
                        <AlertDialogDescription>
                          This action cannot be undone.
                        </AlertDialogDescription>
                      </AlertDialogHeader>
                      <div className="flex justify-end gap-2">
                        <AlertDialogCancel>Cancel</AlertDialogCancel>
                        <AlertDialogAction>Delete</AlertDialogAction>
                      </div>
                    </AlertDialogContent>
                  </AlertDialog>
                </CardContent>
              </Card>

              {/* Sheet */}
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>Sheet</CardTitle>
                  <CardDescription>Side panel overlay</CardDescription>
                </CardHeader>
                <CardContent>
                  <Sheet>
                    <SheetTrigger asChild>
                      <Button>Open Sheet</Button>
                    </SheetTrigger>
                    <SheetContent>
                      <SheetHeader>
                        <SheetTitle>Sheet Title</SheetTitle>
                        <SheetDescription>
                          This is a sheet description
                        </SheetDescription>
                      </SheetHeader>
                      <p>Sheet content goes here</p>
                    </SheetContent>
                  </Sheet>
                </CardContent>
              </Card>

              {/* Tooltip */}
              <Card>
                <CardHeader>
                  <CardTitle>Tooltip</CardTitle>
                  <CardDescription>Hover information</CardDescription>
                </CardHeader>
                <CardContent>
                  <TooltipProvider>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Button variant="outline">Hover me</Button>
                      </TooltipTrigger>
                      <TooltipContent>
                        This is a tooltip
                      </TooltipContent>
                    </Tooltip>
                  </TooltipProvider>
                </CardContent>
              </Card>
            </div>
          )}

          {/* Tables */}
          {selectedCategory === 'tables' && (
            <div className="space-y-8">
              <h2 className="text-2xl font-bold">Tables & Data</h2>
              
              {/* Basic Table */}
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>Basic Table</CardTitle>
                  <CardDescription>Simple data table with status indicators</CardDescription>
                </CardHeader>
                <CardContent>
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Invoice</TableHead>
                        <TableHead>Status</TableHead>
                        <TableHead>Method</TableHead>
                        <TableHead className="text-right">Amount</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      <TableRow>
                        <TableCell className="font-medium">INV001</TableCell>
                        <TableCell>Paid</TableCell>
                        <TableCell>Credit Card</TableCell>
                        <TableCell className="text-right">$250.00</TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell className="font-medium">INV002</TableCell>
                        <TableCell>Pending</TableCell>
                        <TableCell>PayPal</TableCell>
                        <TableCell className="text-right">$150.00</TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell className="font-medium">INV003</TableCell>
                        <TableCell>Unpaid</TableCell>
                        <TableCell>Bank Transfer</TableCell>
                        <TableCell className="text-right">$350.00</TableCell>
                      </TableRow>
                    </TableBody>
                  </Table>
                </CardContent>
              </Card>

              {/* With Footer */}
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>With Footer</CardTitle>
                  <CardDescription>Table with summary row</CardDescription>
                </CardHeader>
                <CardContent>
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Invoice</TableHead>
                        <TableHead>Status</TableHead>
                        <TableHead>Method</TableHead>
                        <TableHead className="text-right">Amount</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      <TableRow>
                        <TableCell className="font-medium">INV001</TableCell>
                        <TableCell>Paid</TableCell>
                        <TableCell>Credit Card</TableCell>
                        <TableCell className="text-right">$250.00</TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell className="font-medium">INV002</TableCell>
                        <TableCell>Pending</TableCell>
                        <TableCell>PayPal</TableCell>
                        <TableCell className="text-right">$150.00</TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell className="font-medium">INV003</TableCell>
                        <TableCell>Unpaid</TableCell>
                        <TableCell>Bank Transfer</TableCell>
                        <TableCell className="text-right">$350.00</TableCell>
                      </TableRow>
                    </TableBody>
                    <TableFooter>
                      <TableRow>
                        <TableCell colSpan={3}>Total</TableCell>
                        <TableCell className="text-right">$750.00</TableCell>
                      </TableRow>
                    </TableFooter>
                  </Table>
                </CardContent>
              </Card>

              {/* Simple */}
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>Simple</CardTitle>
                  <CardDescription>Minimal user list</CardDescription>
                </CardHeader>
                <CardContent>
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Name</TableHead>
                        <TableHead>Email</TableHead>
                        <TableHead>Role</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      <TableRow>
                        <TableCell className="font-medium">Sarah Chen</TableCell>
                        <TableCell>sarah.chen@acme.com</TableCell>
                        <TableCell>Admin</TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell className="font-medium">Marc Rodriguez</TableCell>
                        <TableCell>marcus.rodriguez@acme.com</TableCell>
                        <TableCell>User</TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell className="font-medium">Emily Watson</TableCell>
                        <TableCell>emily.watson@acme.com</TableCell>
                        <TableCell>User</TableCell>
                      </TableRow>
                    </TableBody>
                  </Table>
                </CardContent>
              </Card>

              {/* With Badges */}
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>With Badges</CardTitle>
                  <CardDescription>Status badges in cells</CardDescription>
                </CardHeader>
                <CardContent>
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Task</TableHead>
                        <TableHead>Status</TableHead>
                        <TableHead>Priority</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      <TableRow>
                        <TableCell className="font-medium">Design homepage</TableCell>
                        <TableCell>
                          <Badge>Completed</Badge>
                        </TableCell>
                        <TableCell>
                          <Badge variant="destructive">High</Badge>
                        </TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell className="font-medium">Implement API</TableCell>
                        <TableCell>
                          <Badge variant="secondary">In Progress</Badge>
                        </TableCell>
                        <TableCell>
                          <Badge variant="outline">Medium</Badge>
                        </TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell className="font-medium">Write tests</TableCell>
                        <TableCell>
                          <Badge variant="outline">Pending</Badge>
                        </TableCell>
                        <TableCell>
                          <Badge variant="secondary">Low</Badge>
                        </TableCell>
                      </TableRow>
                    </TableBody>
                  </Table>
                </CardContent>
              </Card>

              {/* With Actions */}
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>With Actions</CardTitle>
                  <CardDescription>Table with dropdown menu</CardDescription>
                </CardHeader>
                <CardContent>
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Product</TableHead>
                        <TableHead>Price</TableHead>
                        <TableHead className="text-right">Actions</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      <TableRow>
                        <TableCell className="font-medium">Wireless Mouse</TableCell>
                        <TableCell>$29.99</TableCell>
                        <TableCell className="text-right">
                          <DropdownMenu>
                            <DropdownMenuTrigger asChild>
                              <Button variant="ghost" size="icon" className="size-8">
                                <MoreHorizontalIcon />
                                <span className="sr-only">Open menu</span>
                              </Button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end">
                              <DropdownMenuItem>Edit</DropdownMenuItem>
                              <DropdownMenuItem>Duplicate</DropdownMenuItem>
                              <DropdownMenuSeparator />
                              <DropdownMenuItem variant="destructive">Delete</DropdownMenuItem>
                            </DropdownMenuContent>
                          </DropdownMenu>
                        </TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell className="font-medium">Mechanical Keyboard</TableCell>
                        <TableCell>$129.99</TableCell>
                        <TableCell className="text-right">
                          <DropdownMenu>
                            <DropdownMenuTrigger asChild>
                              <Button variant="ghost" size="icon" className="size-8">
                                <MoreHorizontalIcon />
                                <span className="sr-only">Open menu</span>
                              </Button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end">
                              <DropdownMenuItem>Edit</DropdownMenuItem>
                              <DropdownMenuItem>Duplicate</DropdownMenuItem>
                              <DropdownMenuSeparator />
                              <DropdownMenuItem variant="destructive">Delete</DropdownMenuItem>
                            </DropdownMenuContent>
                          </DropdownMenu>
                        </TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell className="font-medium">USB-C Hub</TableCell>
                        <TableCell>$49.99</TableCell>
                        <TableCell className="text-right">
                          <DropdownMenu>
                            <DropdownMenuTrigger asChild>
                              <Button variant="ghost" size="icon" className="size-8">
                                <MoreHorizontalIcon />
                                <span className="sr-only">Open menu</span>
                              </Button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end">
                              <DropdownMenuItem>Edit</DropdownMenuItem>
                              <DropdownMenuItem>Duplicate</DropdownMenuItem>
                              <DropdownMenuSeparator />
                              <DropdownMenuItem variant="destructive">Delete</DropdownMenuItem>
                            </DropdownMenuContent>
                          </DropdownMenu>
                        </TableCell>
                      </TableRow>
                    </TableBody>
                  </Table>
                </CardContent>
              </Card>

              {/* With Select */}
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>With Select</CardTitle>
                  <CardDescription>Inline select controls</CardDescription>
                </CardHeader>
                <CardContent>
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Task</TableHead>
                        <TableHead>Assigned To</TableHead>
                        <TableHead>Status</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      <TableRow>
                        <TableCell className="font-medium">Design homepage</TableCell>
                        <TableCell>Sarah Chen</TableCell>
                        <TableCell>
                          <Select defaultValue="progress">
                            <SelectTrigger className="w-[140px]">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectItem value="progress">In Progress</SelectItem>
                              <SelectItem value="pending">Pending</SelectItem>
                              <SelectItem value="not-started">Not Started</SelectItem>
                            </SelectContent>
                          </Select>
                        </TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell className="font-medium">Implement API</TableCell>
                        <TableCell>Marc Rodriguez</TableCell>
                        <TableCell>
                          <Select defaultValue="pending">
                            <SelectTrigger className="w-[140px]">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectItem value="progress">In Progress</SelectItem>
                              <SelectItem value="pending">Pending</SelectItem>
                              <SelectItem value="not-started">Not Started</SelectItem>
                            </SelectContent>
                          </Select>
                        </TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell className="font-medium">Write tests</TableCell>
                        <TableCell>Emily Watson</TableCell>
                        <TableCell>
                          <Select defaultValue="not-started">
                            <SelectTrigger className="w-[140px]">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectItem value="progress">In Progress</SelectItem>
                              <SelectItem value="pending">Pending</SelectItem>
                              <SelectItem value="not-started">Not Started</SelectItem>
                            </SelectContent>
                          </Select>
                        </TableCell>
                      </TableRow>
                    </TableBody>
                  </Table>
                </CardContent>
              </Card>

              {/* With Input */}
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>With Input</CardTitle>
                  <CardDescription>Editable quantity fields</CardDescription>
                </CardHeader>
                <CardContent>
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Product</TableHead>
                        <TableHead>Quantity</TableHead>
                        <TableHead className="text-right">Total</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      <TableRow>
                        <TableCell className="font-medium">Wireless Mouse</TableCell>
                        <TableCell>
                          <Input type="number" defaultValue="1" className="w-20" />
                        </TableCell>
                        <TableCell className="text-right">$29.99</TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell className="font-medium">Mechanical Keyboard</TableCell>
                        <TableCell>
                          <Input type="number" defaultValue="2" className="w-20" />
                        </TableCell>
                        <TableCell className="text-right">$129.99</TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell className="font-medium">USB-C Hub</TableCell>
                        <TableCell>
                          <Input type="number" defaultValue="1" className="w-20" />
                        </TableCell>
                        <TableCell className="text-right">$49.99</TableCell>
                      </TableRow>
                    </TableBody>
                  </Table>
                </CardContent>
              </Card>
            </div>
          )}

          {/* Complex Components */}
          {selectedCategory === 'complex' && (
            <div className="space-y-8">
              <h2 className="text-2xl font-bold">Complex Components</h2>
              
              <Card>
                <CardHeader>
                  <CardTitle>Advanced Components</CardTitle>
                  <CardDescription>
                    Complex components like calendar, carousel, command, pagination, table, etc.
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <p className="text-muted-foreground">
                    These components are installed and available. See component files in src/components/ui/
                  </p>
                  <div className="mt-4 grid grid-cols-2 gap-2 text-sm">
                    {[
                      'accordion', 'calendar', 'carousel', 'command',
                      'context-menu', 'navigation-menu',
                      'pagination', 'popover', 'progress', 'scroll-area',
                      'slider', 'sonner', 'toggle-group'
                    ].map(comp => (
                      <div key={comp} className="flex items-center gap-2">
                        <Badge variant="secondary">{comp}</Badge>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            </div>
          )}

          {/* Status Section */}
          <div className="mt-12 p-6 bg-muted rounded-lg">
            <h3 className="font-bold mb-2">Component Status</h3>
            <ul className="text-sm text-muted-foreground space-y-1">
              <li>✅ 42 shadcn components installed</li>
              <li>✅ All foundations (badge, button, card, separator, skeleton)</li>
              <li>✅ All form components (input, select, checkbox, radio, switch, textarea)</li>
              <li>✅ All overlays (dialog, sheet, alert dialog, tooltip)</li>
              <li>✅ Production ready for Phlex integration</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  )
}
