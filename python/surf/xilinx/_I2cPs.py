#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
# Based on Xilinx/embeddedsw driver:
# https://github.com/Xilinx/embeddedsw/blob/master/XilinxProcessorIPLib/drivers/iicps/src/xiicps.c
# https://www.xilinx.com/htmldocs/registers/ug1087/ug1087-zynq-ultrascale-registers.html#mod___i2c.html
# https://www.realdigital.org/doc/1d42829ddc326b373960f69c7149f7b1
#-----------------------------------------------------------------------------
# Virtual Address Decoding:
#   ADDR[50:48] = I2C Device Index
#   ADDR[46:44] = I2C Address Bytes
#   ADDR[43:40] = I2C Data Bytes
#   ADDR[33:02] = I2C Address available
#   ADDR[01:00] = Unused (32-bit word alignment)
#-----------------------------------------------------------------------------

import pyrogue as pr
import rogue

import threading
import time
import queue

class _Regs(pr.Device):
    def __init__(self,
            pollPeriod = 0.0,
            **kwargs):
        super().__init__(**kwargs)

        self._pollPeriod = pollPeriod

        self._queue = queue.Queue()
        self._pollThread = threading.Thread(target=self._pollWorker)
        self._pollThread.start()

        ####################################################################

        self.add(pr.RemoteVariable(
            name        = 'divisor_a',
            description = 'Divisor for stage A clock divider: 0 - 3: Divides the input APB bus clock frequency by divisor_a + 1.',
            offset      = 0x00,
            bitOffset   = 14,
            bitSize     = 2,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'divisor_b',
            description = 'Divisor for stage B clock divider: 0 - 63: Divides the output frequency from divisor_a by divisor_b + 1.',
            offset      = 0x00,
            bitOffset   = 8,
            bitSize     = 6,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CLR_FIFO',
            description = '1: initialize the FIFO to all zeros and clears the transfer size register; self-clearing bit.',
            offset      = 0x00,
            bitOffset   = 6,
            bitSize     = 1,
            mode        = 'WO',
        ))
    
        self.add(pr.RemoteVariable(
            name        = 'SLVMON',
            description = 'Slave monitor mode',
            offset      = 0x00,
            bitOffset   = 5,
            bitSize     = 1,
            mode        = 'RW',
            enum        = {
                0: "normal operation",
                1: "monitor mode",
            },
        )) 

        self.add(pr.RemoteVariable(
            name        = 'HOLD',
            description  = """
                hold_bus
                1 - when no more data is available for transmit or no more data can be received, hold the sclk line low until serviced by the host.
                0 - allow the transfer to terminate as soon as all the data has been transmitted or received. """,
            offset      = 0x00,
            bitOffset   = 4,
            bitSize     = 1,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name        = 'ACK_EN',
            description  = """
                This bit needs to be set to 1
                1 - acknowledge enabled, ACK transmitted
                0 - acknowledge disabled, NACK transmitted. """,
            offset      = 0x00,
            bitOffset   = 3,
            bitSize     = 1,
            mode        = 'RW',
        ))          
        
        self.add(pr.RemoteVariable(
            name        = 'NEA',
            description  = """
                Addressing mode: This bit is used in master mode only.
                1 - normal (7-bit) address
                0 - extended (10-bit) address """,
            offset      = 0x00,
            bitOffset   = 2,
            bitSize     = 1,
            mode        = 'RW',
        ))          
        
        self.add(pr.RemoteVariable(
            name        = 'MS',
            description = 'Slave monitor mode',
            offset      = 0x00,
            bitOffset   = 1,
            bitSize     = 1,
            mode        = 'RW',
            enum        = {
                0: "slave",
                1: "master",
            },
        ))         

        self.add(pr.RemoteVariable(
            name        = 'RW',
            description = 'Direction of transfer',
            offset      = 0x00,
            bitOffset   = 1,
            bitSize     = 1,
            mode        = 'RW',
            enum        = {
                0: "master transmitter",
                1: "master receiver",
            },
        ))

        ####################################################################
        
        # self.add(pr.RemoteVariable(
            # name        = 'BA',
            # description = 'Bus Active: 1 - ongoing transfer on the I2C bus.',
            # offset      = 0x04,
            # bitOffset   = 8,
            # bitSize     = 1,
            # mode        = 'RO',
            # base        = pr.Bool,
        # ))

        # self.add(pr.RemoteVariable(
            # name        = 'RXOVF',
            # description = 'Receiver Overflow: 1 - This bit is set whenever FIFO is full and a new byte is received. The new byte is not acknowledged and contents of the FIFO remains unchanged.',
            # offset      = 0x04,
            # bitOffset   = 7,
            # bitSize     = 1,
            # mode        = 'RO',
            # base        = pr.Bool,
        # ))

        # self.add(pr.RemoteVariable(
            # name        = 'TXDV',
            # description  = """
                # Transmit Data Valid - SW should not use this to determine data completion, it is the RAW value on the interface.
                # Please use COMP in the ISR.
                # 1 - still a byte of data to be transmitted by the interface. """,
            # offset      = 0x04,
            # bitOffset   = 6,
            # bitSize     = 1,
            # mode        = 'RO',
            # base        = pr.Bool,
        # ))  

        # self.add(pr.RemoteVariable(
            # name        = 'RXDV',
            # description = 'Receiver Data Valid: 1 -valid, new data to be read from the interface.',
            # offset      = 0x04,
            # bitOffset   = 5,
            # bitSize     = 1,
            # mode        = 'RO',
            # base        = pr.Bool,
        # )) 

        # self.add(pr.RemoteVariable(
            # name        = 'RXRW',
            # description = 'RX read_write: 1 - mode of the transmission received from a master.',
            # offset      = 0x04,
            # bitOffset   = 3,
            # bitSize     = 1,
            # mode        = 'RO',
            # base        = pr.Bool,
        # ))         
        
        # ####################################################################
        
        # self.add(pr.RemoteVariable(
            # name        = 'ADD',
            # description = 'Address: 0 - 1024: Normal addressing mode uses add[6:0]. Extended addressing mode uses add[9:0].',
            # offset      = 0x08,
            # bitOffset   = 0,
            # bitSize     = 10,
            # mode        = 'RW',
        # ))   

        # self.add(pr.RemoteVariable(
            # name        = 'DATA',
            # description = 'data: 0 -255: When written to, the data register sets data to transmit. When read from, the data register reads the last received byte of data.',
            # offset      = 0x0C,
            # bitOffset   = 0,
            # bitSize     = 8,
            # mode        = 'RW',
        # ))           
        
        # self.add(pr.RemoteVariable(
            # name        = 'ISR',
            # description = 'Interrupt Status Register',
            # offset      = 0x10,
            # bitOffset   = 0,
            # bitSize     = 10,
            # mode        = 'RW',
            # verify      = False, # Readable, write 1 to clear
        # ))        
        
        # self.add(pr.RemoteVariable(
            # name        = 'Transfer_Size',
            # description = 'Transfer Size: 0-255 (zero inclusive)',
            # offset      = 0x14,
            # bitOffset   = 0,
            # bitSize     = 8,
            # mode        = 'RW',
        # ))
        
        # self.add(pr.RemoteVariable(
            # name        = 'Pause',
            # description = 'pause interval: 0 - 7: pause interval',
            # offset      = 0x18,
            # bitOffset   = 0,
            # bitSize     = 4,
            # mode        = 'RW',
        # ))   

        # self.add(pr.RemoteVariable(
            # name        = 'TO',
            # description = 'Timeout Period Range: 10h to 7Fh.',
            # offset      = 0x1C,
            # bitOffset   = 0,
            # bitSize     = 8,
            # mode        = 'RW',
        # ))           
        
        # self.add(pr.RemoteVariable(
            # name        = 'IMR',
            # description = 'Interrupt Mask Register',
            # offset      = 0x20,
            # bitOffset   = 0,
            # bitSize     = 10,
            # mode        = 'RO',
        # ))        
        
        # self.add(pr.RemoteVariable(
            # name        = 'IER',
            # description = 'Interrupt Enable Register',
            # offset      = 0x24,
            # bitOffset   = 0,
            # bitSize     = 10,
            # mode        = 'WO',
        # ))     

        # self.add(pr.RemoteVariable(
            # name        = 'IDR',
            # description = 'Interrupt Disable Register',
            # offset      = 0x28,
            # bitOffset   = 0,
            # bitSize     = 10,
            # mode        = 'WO',
        # ))             
        
        # self.add(pr.RemoteVariable(
            # name        = 'GF',
            # description  = """
                # Length of the glitch filter shift register.
                # The filter length is specified in terms of APB interface clock cycles (LPD_LSBUS).
                # The default value is 5. If it is set to zero (0x0) then the glitch filter is bypassed. """,
            # offset      = 0x2C,
            # bitOffset   = 0,
            # bitSize     = 4,
            # mode        = 'RW',
        # ))          

    ####################################################################

    def transfer(self, csValue, txBuffer, byteSize):

        # # Clear the FIFO
        # self.CLR_FIFO.set(1)
        
        # if self.RXWR.value() != byteSize:
            # self.RXWR.set(byteSize)

        # # Set CS
        # if self.CS.value() != csValue:
            # self.CS.set(csValue)

        # # Load the TX FIFO
        # self.Man_start_en.set(1)
        # for i in range(byteSize):
            # self.TXD.set(txBuffer[i])

        # # Start the transfer
        # self.Manual_CS.set(1) # Force manual due to observed CS glitch in waveforms when AUTO CS
        # self.Man_start_en.set(0)

        # # Create the RX buffer and clear the "Rx FIFO Not Empty" flag
        # rxBuffer = [None for x in range(byteSize)]
        # # self.SR.set(0x10)

        # # Wait for the buffer to fill out: Rx FIFO Not Empty = 0x10
        # while ( (self.SR.get(read=True) & 0x10) == 0 ):
            # time.sleep(self._pollPeriod)

        # # Read the RX FIFO
        # self.Manual_CS.set(0) # release manual due to observed CS glitch in waveforms when AUTO CS
        # for i in range(byteSize):
            # rxBuffer[i] = self.RXD.get(read=True)



        rxBuffer  = [0x00 for x in range(byteSize)]

        # Return the RX buffer
        return rxBuffer

    ####################################################################

    def proxyTransaction(self, transaction):
        self._queue.put(transaction)

    def _pollWorker(self):
        while True:
            #print('Main thread loop start')
            transaction = self._queue.get()
            if transaction is None:
                return

            with self._memLock, transaction.lock():
                #tranId = transaction.id()
                #print(f'Woke the pollWorker with id: {tranId}')

                # Get the transaction virtual address
                virtualAddress = transaction.address()

                # Decode the  virtual address metadata
                devIdx    = (virtualAddress >> 48) & 0x7
                addrBytes = (virtualAddress >> 44) & 0x7
                dataBytes = (virtualAddress >> 40) & 0x7
                byteSize  = addrBytes + dataBytes
                txBuffer  = [0x00 for x in range(byteSize)]

                # Fill the address bytes
                for i in range(addrBytes):
                    txBuffer[i] = ( virtualAddress >> ( 8*(addrBytes-1-i) )+2 ) & 0xFF

                # Check for write transaction
                if transaction.type() == rogue.interfaces.memory.Write:
                    # Convert data bytes to int and write data to proxy register
                    dataBa = bytearray(4)
                    transaction.getData(dataBa, 0)
                    data = int.from_bytes(dataBa, 'little', signed=False)

                    # Fill the data bytes
                    for i in range(dataBytes):
                        txBuffer[i+addrBytes] = ( data >> ( 8*(dataBytes-1-i) ) ) & 0xFF

                    #print(f'Started write transaction: {tranId}')

                # Check for read or verify transaction
                elif (transaction.type() == rogue.interfaces.memory.Read) or (transaction.type() == rogue.interfaces.memory.Verify):

                    # Set the R/W bit
                    txBuffer[0] |= 0x80
                    #print(f'Started read transaction: {tranId}')

                else:
                    # Post transactions not allowed
                    transaction.error(f'Unsupported transaction type {transaction.type()}')
                    return

                # Kick off the proxy transaction
                rxBuffer = self.transfer((0xF ^ 0x1 <<devIdx), txBuffer, byteSize)

                # Check the error flag
                resp = (self.SR.get(read=True) & 0x2)

                # Clear status register by writing 1 to the write to clear bits
                self.SR.set(0x7F)

                #print(f'Resp: {resp}')
                if resp != 0:
                    self.ResetHw()
                    transaction.error(f'AXIL tranaction failed with RESP: {resp}')

                # Finish the transaction
                elif transaction.type() == rogue.interfaces.memory.Write:
                    transaction.done()

                else:
                    # parse the rxBuffer
                    data = 0x0
                    for i in range(dataBytes):
                        data = (data << 8) | rxBuffer[i+addrBytes]

                    #print(f'Got read data: {data:x}')
                    dataBa = bytearray(data.to_bytes(4, 'little', signed=False))

                    #print(dataBa)
                    transaction.setData(dataBa, 0)
                    transaction.done()

    def _stop(self):
        self._queue.put(None)
        self._pollThread.join()

class _ProxySlave(rogue.interfaces.memory.Slave):

    def __init__(self, regs):
        super().__init__(4,4)
        self._regs = regs

    def _doTransaction(self, transaction):
        #print('_ProxySlave._doTransaction')
        self._regs.proxyTransaction(transaction)

class I2cPs(pr.Device):

    def __init__(self,
            hidden     = True,
            initCtrl   = False,
            pollPeriod = 0.0,
            **kwargs):
        super().__init__(hidden=hidden, **kwargs)

        self.add(_Regs(
            name       = 'Regs',
            memBase    = self,
            offset     = 0x0000,
            hidden     = hidden,
            pollPeriod = pollPeriod,
            expand     = False,
        ))
        self.proxy = _ProxySlave(self.Regs)
        self.initCtrl = initCtrl

    def add(self, node):
        pr.Node.add(self, node)

        if isinstance(node, pr.Device):
            if node._memBase is None:
                node._setSlave(self.proxy)

    def Init(self):
        if (self.initCtrl):
            print( f'{self.path}: I2C Controller init() not supported yet' )
