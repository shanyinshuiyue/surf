-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Asynchronous bridge for AXI Lite bus. Allows AXI transactions to cross
-- a clock boundary.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity AxiLitePipeline is
   generic (
      TPD_G    : time                  := 1 ns;
      STAGES_G : integer range 0 to 16 := 2);
   port (
      -- Slave Port
      axiClk          : in  sl;
      axiRst          : in  sl;
      sAxiReadMaster  : in  AxiLiteReadMasterType;
      sAxiReadSlave   : out AxiLiteReadSlaveType;
      sAxiWriteMaster : in  AxiLiteWriteMasterType;
      sAxiWriteSlave  : out AxiLiteWriteSlaveType;
      mAxiReadMaster  : out AxiLiteReadMasterType;
      mAxiReadSlave   : in  AxiLiteReadSlaveType;
      mAxiWriteMaster : out AxiLiteWriteMasterType;
      mAxiWriteSlave  : in  AxiLiteWriteSlaveType);
end AxiLitePipeline;

architecture STRUCTURE of AxiLitePipeline is

   signal axiReadMaster  : AxiLiteReadMasterArray(STAGES_G downto 0);
   signal axiReadSlave   : AxiLiteReadSlaveArray(STAGES_G downto 0);
   signal axiWriteMaster : AxiLiteWriteMasterArray(STAGES_G downto 0);
   signal axiWriteSlave  : AxiLiteWriteSlaveArray(STAGES_G downto 0);

begin

   PASSTHROUGH: if (STAGES_G = 0) generate

      mAxiReadMaster <= sAxiReadMaster;
      sAxiReadSlave <= mAxiReadSlave;
      mAxiWriteMaster <= sAxiWriteMaster;
      sAxiWriteSlave <= mAxiWriteSlave;
      
   end generate;

   GEN_PIPELINE: if (STAGES_G > 0) generate
      


   axiReadMaster(STAGES_G)  <= sAxiReadMaster;
   sAxiReadSlave            <= axiReadSlave(0);
   axiWriteMaster(STAGES_G) <= sAxiWriteMaster;
   sAxiWriteSlave           <= axiWriteSlave(0);

   mAxiReadMaster          <= axiReadMaster(0);
   axiReadSlave(STAGES_G)  <= mAxiReadSlave;
   mAxiWriteMaster         <= axiWriteMaster(0);
   axiWriteSlave(STAGES_G) <= mAxiWriteSlave;



   GEN_STAGES : for i in STAGES_G-1 downto 0 generate

      ----------------------------------------------------------------------------------------------
      -- AxilReadMaster
      ----------------------------------------------------------------------------------------------
      U_RegisterVector_ARADDR : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 32)
         port map (
            clk   => axiClk,                     -- [in]
            rst   => axiRst,                     -- [in]
            sig_i => axiReadMaster(i+1).araddr,  -- [in]
            reg_o => axiReadMaster(i).araddr);   -- [out]

      U_RegisterVector_ARPROT : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 3)
         port map (
            clk   => axiClk,                     -- [in]
            rst   => axiRst,                     -- [in]
            sig_i => axiReadMaster(i+1).arprot,  -- [in]
            reg_o => axiReadMaster(i).arprot);   -- [out]

      U_RegisterVector_ARVALID : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 1)
         port map (
            clk      => axiClk,                      -- [in]
            rst      => axiRst,                      -- [in]
            sig_i(0) => axiReadMaster(i+1).arvalid,  -- [in]
            reg_o(0) => axiReadMaster(i).arvalid);   -- [out]

      U_RegisterVector_RREADY : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 1)
         port map (
            clk      => axiClk,                     -- [in]
            rst      => axiRst,                     -- [in]
            sig_i(0) => axiReadMaster(i+1).rready,  -- [in]
            reg_o(0) => axiReadMaster(i).rready);   -- [out]

      ----------------------------------------------------------------------------------------------
      -- AxilReadSlave
      ----------------------------------------------------------------------------------------------
      U_RegisterVector_ARREADY : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 1)
         port map (
            clk      => axiClk,                     -- [in]
            rst      => axiRst,                     -- [in]
            sig_i(0) => axiReadSlave(i+1).arready,  -- [in]
            reg_o(0) => axiReadSlave(i).arready);   -- [out]

      U_RegisterVector_RDATA : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 32)
         port map (
            clk   => axiClk,                   -- [in]
            rst   => axiRst,                   -- [in]
            sig_i => axiReadSlave(i+1).rdata,  -- [in]
            reg_o => axiReadSlave(i).rdata);   -- [out]

      U_RegisterVector_RRESP : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 2)
         port map (
            clk   => axiClk,                   -- [in]
            rst   => axiRst,                   -- [in]
            sig_i => axiReadSlave(i+1).rresp,  -- [in]
            reg_o => axiReadSlave(i).rresp);   -- [out]

      U_RegisterVector_RVALID : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 1)
         port map (
            clk      => axiClk,                    -- [in]
            rst      => axiRst,                    -- [in]
            sig_i(0) => axiReadSlave(i+1).rvalid,  -- [in]
            reg_o(0) => axiReadSlave(i).rvalid);   -- [out]

      ----------------------------------------------------------------------------------------------
      -- AxiWriteMaster
      ----------------------------------------------------------------------------------------------
      U_RegisterVector_AWADDR : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 32)
         port map (
            clk      => axiClk,                      -- [in]
            rst      => axiRst,                      -- [in]
            sig_i => axiWriteMaster(i+1).awaddr,  -- [in]
            reg_o => axiWriteMaster(i).awaddr);   -- [out]
      
      U_RegisterVector_AWPROT : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 3)
         port map (
            clk      => axiClk,                      -- [in]
            rst      => axiRst,                      -- [in]
            sig_i => axiWriteMaster(i+1).awprot,  -- [in]
            reg_o => axiWriteMaster(i).awprot);   -- [out]
      
      U_RegisterVector_AWVALID : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 1)
         port map (
            clk      => axiClk,                      -- [in]
            rst      => axiRst,                      -- [in]
            sig_i(0) => axiWriteMaster(i+1).awvalid,  -- [in]
            reg_o(0) => axiWriteMaster(i).awvalid);   -- [out]
      
      U_RegisterVector_WDATA : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 32)
         port map (
            clk      => axiClk,                      -- [in]
            rst      => axiRst,                      -- [in]
            sig_i => axiWriteMaster(i+1).wdata,  -- [in]
            reg_o => axiWriteMaster(i).wdata);   -- [out]
      
      U_RegisterVector_WSTRB : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 4)
         port map (
            clk      => axiClk,                      -- [in]
            rst      => axiRst,                      -- [in]
            sig_i => axiWriteMaster(i+1).wstrb,  -- [in]
            reg_o => axiWriteMaster(i).wstrb);   -- [out]
      
      U_RegisterVector_WVALID : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 1)
         port map (
            clk      => axiClk,                      -- [in]
            rst      => axiRst,                      -- [in]
            sig_i(0) => axiWriteMaster(i+1).wvalid,  -- [in]
            reg_o(0) => axiWriteMaster(i).wvalid);   -- [out]
      
      U_RegisterVector_BREADY : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 1)
         port map (
            clk      => axiClk,                      -- [in]
            rst      => axiRst,                      -- [in]
            sig_i(0) => axiWriteMaster(i+1).bready,  -- [in]
            reg_o(0) => axiWriteMaster(i).bready);   -- [out]

      ----------------------------------------------------------------------------------------------
      -- AxiWriteSlave
      ----------------------------------------------------------------------------------------------
      U_RegisterVector_AWREADY : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 1)
         port map (
            clk      => axiClk,                      -- [in]
            rst      => axiRst,                      -- [in]
            sig_i(0) => axiWriteSlave(i+1).awready,  -- [in]
            reg_o(0) => axiWriteSlave(i).awready);   -- [out]

      U_RegisterVector_WREADY : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 1)
         port map (
            clk      => axiClk,                     -- [in]
            rst      => axiRst,                     -- [in]
            sig_i(0) => axiWriteSlave(i+1).wready,  -- [in]
            reg_o(0) => axiWriteSlave(i).wready);   -- [out]

      U_RegisterVector_BRESP : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 2)
         port map (
            clk   => axiClk,                    -- [in]
            rst   => axiRst,                    -- [in]
            sig_i => axiWriteSlave(i+1).bresp,  -- [in]
            reg_o => axiWriteSlave(i).bresp);   -- [out]

      U_RegisterVector_BVALID : entity surf.RegisterVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 1)
         port map (
            clk      => axiClk,                     -- [in]
            rst      => axiRst,                     -- [in]
            sig_i(0) => axiWriteSlave(i+1).bvalid,  -- [in]
            reg_o(0) => axiWriteSlave(i).bvalid);   -- [out]

   end generate;
   end generate GEN_PIPELINE;

end architecture STRUCTURE;
